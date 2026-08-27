//! Limitador de peticiones en memoria, por ventana deslizante.
//!
//! Se usa de **dos formas distintas, y la diferencia importa**:
//!
//! - **Por IP**, en los endpoints de auth (`/auth/login`, `/auth/register`,
//!   `/auth/email-available`). Ahí todavía no hay usuario: quien ataca está
//!   justamente probando cuál existe, así que lo único que identifica al que
//!   llama es de dónde viene.
//! - **Por usuario**, en los endpoints autenticados y caros o abusables
//!   (subir fotos, swipes, mensajes, reportes). Aquí limitar por IP sería
//!   peor por los dos lados: media ciudad puede compartir IP detrás de
//!   CGNAT, y a la vez cambiar de IP es trivial para quien quiere abusar.
//!   El identificador honesto es la cuenta.
//!
//! Sin crate nueva: un `Mutex<HashMap<String, Vec<Instant>>>` sobra para un
//! despliegue de una sola instancia. **Aviso para cuando haya más de una:**
//! como cada proceso lleva su propia cuenta, con N instancias el límite
//! efectivo es N veces el que dice aquí, y habría que moverlo a un almacén
//! compartido (Redis o similar).
//!
//! Qué IP cuenta como "el cliente" depende de `TRUST_PROXY`; ver [`client_ip`].

use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::{
    extract::{ConnectInfo, Request, State},
    http::StatusCode,
    middleware::Next,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use tokio::sync::Mutex;

use crate::auth::jwt::AuthUser;
use crate::state::AppState;

/// Cuántas peticiones se permiten en cuánto tiempo.
#[derive(Clone, Copy)]
pub struct Quota {
    pub max: usize,
    pub window: Duration,
}

const fn per_minute(max: usize) -> Quota {
    Quota {
        max,
        window: Duration::from_secs(60),
    }
}

const fn per_hour(max: usize) -> Quota {
    Quota {
        max,
        window: Duration::from_secs(3600),
    }
}

/// Auth: fuerza bruta y enumeración de cuentas.
pub const AUTH: Quota = per_minute(10);

/// Swipes. Deslizar es rápido y en una sesión normal se encadenan varios
/// seguidos, así que el tope es alto: sólo pretende cortar a un script,
/// no a alguien con prisa.
pub const SWIPES: Quota = per_minute(60);

/// Mensajes. Muy por encima de lo que escribe una persona en un minuto.
pub const MESSAGES: Quota = per_minute(30);

/// Fotos. Es el endpoint más caro (escribe en disco) y el perfil admite 6 en
/// total, así que 20 a la hora ya deja sitio de sobra para reordenar o
/// arrepentirse. Sin esto, una cuenta puede llenar el volumen — que en
/// Railway se paga.
pub const PHOTOS: Quota = per_hour(20);

/// Densidad ("cuánta gente hay cerca de aquí"). Mucho más suelta que la de
/// auth, y a propósito: es una consulta de sólo lectura que devuelve un
/// número, y quien la llama es el paso de ubicación del registro, donde mover
/// el radio o cambiar de sitio son gestos normales que se repiten. Con la
/// cuota de auth (10/min) bastaba con arrastrar el slider un rato para
/// quedarse sin contador el resto del minuto — que es justo el momento en que
/// alguien está decidiendo si la app le sirve.
pub const DENSITY: Quota = per_minute(60);

/// Reportes. Denunciar es legítimo, pero denunciar 500 veces es acoso o
/// ruido para quien luego tenga que revisarlos.
pub const REPORTS: Quota = per_hour(10);

/// La ventana más larga de todas las cuotas, para la limpieza periódica.
const LONGEST_WINDOW: Duration = Duration::from_secs(3600);

#[derive(Clone)]
pub struct RateLimiter(Arc<Mutex<HashMap<String, Vec<Instant>>>>);

impl RateLimiter {
    pub fn new() -> Self {
        let limiter = Self(Arc::new(Mutex::new(HashMap::new())));

        // Barrido periódico para que las claves que dejan de aparecer no se
        // queden en el mapa para siempre — `check` sólo poda el cubo que
        // acaba de tocar. Se usa la ventana más larga: podar antes borraría
        // el historial de las cuotas por hora.
        let background = limiter.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(LONGEST_WINDOW).await;
                let mut buckets = background.0.lock().await;
                let now = Instant::now();
                buckets.retain(|_, hits| {
                    hits.retain(|t| now.duration_since(*t) < LONGEST_WINDOW);
                    !hits.is_empty()
                });
            }
        });

        limiter
    }

    /// `Ok(())` si cabe; `Err(espera)` con lo que falta para que vuelva a
    /// haber sitio. Devolver el tiempo permite contestar algo útil en vez de
    /// un 429 pelado.
    async fn check(&self, key: String, quota: Quota) -> Result<(), Duration> {
        let mut buckets = self.0.lock().await;
        let now = Instant::now();
        let hits = buckets.entry(key).or_default();
        hits.retain(|t| now.duration_since(*t) < quota.window);

        if hits.len() >= quota.max {
            // El hueco se libera cuando caduque el más antiguo del cubo.
            let oldest = hits[0];
            return Err(quota.window - now.duration_since(oldest));
        }

        hits.push(now);
        Ok(())
    }
}

impl Default for RateLimiter {
    fn default() -> Self {
        Self::new()
    }
}

/// De qué IP viene realmente la petición.
///
/// `ConnectInfo` da la IP de la conexión TCP, que detrás de un proxy o un
/// balanceador es la del proxy **para todos los clientes**: el límite
/// dejaría de ser por cliente y el primero en pasarse bloquearía los
/// intentos de login de todo el mundo. Con un proxy delante hay que leer
/// `X-Forwarded-For`, cuyo primer valor es el cliente original.
///
/// Pero esa cabecera la pone quien llama, así que hacerle caso sin proxy
/// delante permitiría saltarse el límite mandando una IP inventada
/// distinta en cada intento — justo lo contrario de lo que se busca. De
/// ahí que dependa de `TRUST_PROXY`, que sólo debe activarse cuando de
/// verdad hay algo delante que la reescribe.
fn client_ip(state: &AppState, req: &Request, connect_addr: SocketAddr) -> IpAddr {
    if !state.config.trust_proxy {
        return connect_addr.ip();
    }

    req.headers()
        .get("x-forwarded-for")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.split(',').next())
        .and_then(|first| first.trim().parse::<IpAddr>().ok())
        .unwrap_or_else(|| connect_addr.ip())
}

fn too_many(retry_after: Duration) -> Response {
    let secs = retry_after.as_secs().max(1);
    (
        StatusCode::TOO_MANY_REQUESTS,
        // `Retry-After` es la cabecera estándar; el mensaje va además en el
        // cuerpo porque es lo que el cliente enseña tal cual.
        [("retry-after", secs.to_string())],
        Json(json!({
            "message": format!("Demasiadas peticiones. Inténtalo de nuevo en {secs} s.")
        })),
    )
        .into_response()
}

/// Middleware por IP, para los endpoints de auth.
pub async fn rate_limit(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    req: Request,
    next: Next,
) -> Response {
    let ip = client_ip(&state, &req, addr);
    match state.rate_limiter.check(format!("ip:{ip}"), AUTH).await {
        Ok(()) => next.run(req).await,
        Err(retry) => too_many(retry),
    }
}

/// Middleware por IP para `/discover/density`, con su propia cuota.
///
/// Cubo separado del de auth (`density:` en vez de `ip:`) para que gastar
/// consultas de densidad no deje a nadie sin poder iniciar sesión, ni al
/// revés.
pub async fn density_rate_limit(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    req: Request,
    next: Next,
) -> Response {
    let ip = client_ip(&state, &req, addr);
    match state
        .rate_limiter
        .check(format!("density:{ip}"), DENSITY)
        .await
    {
        Ok(()) => next.run(req).await,
        Err(retry) => too_many(retry),
    }
}

/// Núcleo de los middlewares por usuario.
///
/// El `AuthUser` del parámetro hace que esto corra **después** de validar el
/// token, así que un token inválido se rechaza antes de gastar cuota — si no,
/// cualquiera podría agotar el límite de otra persona a base de peticiones
/// sin autenticar.
async fn limit_by_user(
    state: AppState,
    user: AuthUser,
    bucket: &str,
    quota: Quota,
    req: Request,
    next: Next,
) -> Response {
    let key = format!("{bucket}:{}", user.user_id);
    match state.rate_limiter.check(key, quota).await {
        Ok(()) => next.run(req).await,
        Err(retry) => too_many(retry),
    }
}

macro_rules! per_user_middleware {
    ($name:ident, $bucket:literal, $quota:expr) => {
        pub async fn $name(
            State(state): State<AppState>,
            user: AuthUser,
            req: Request,
            next: Next,
        ) -> Response {
            limit_by_user(state, user, $bucket, $quota, req, next).await
        }
    };
}

per_user_middleware!(limit_swipes, "swipes", SWIPES);
per_user_middleware!(limit_messages, "messages", MESSAGES);
per_user_middleware!(limit_photos, "photos", PHOTOS);
per_user_middleware!(limit_reports, "reports", REPORTS);

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn deja_pasar_hasta_el_tope_y_luego_corta() {
        let limiter = RateLimiter::new();
        let quota = per_minute(3);

        for _ in 0..3 {
            assert!(limiter.check("k".into(), quota).await.is_ok());
        }
        assert!(limiter.check("k".into(), quota).await.is_err());
    }

    /// Lo que hace que limitar por usuario tenga sentido: que la cuenta de
    /// uno no gaste la del otro.
    #[tokio::test]
    async fn las_claves_no_se_pisan() {
        let limiter = RateLimiter::new();
        let quota = per_minute(1);

        assert!(limiter.check("a".into(), quota).await.is_ok());
        assert!(limiter.check("a".into(), quota).await.is_err());
        assert!(limiter.check("b".into(), quota).await.is_ok());
    }

    /// Y que los distintos endpoints de un mismo usuario tampoco compartan
    /// cubo: subir una foto no debe consumir tus mensajes.
    #[tokio::test]
    async fn los_cubos_de_un_mismo_usuario_son_independientes() {
        let limiter = RateLimiter::new();
        let quota = per_minute(1);

        assert!(limiter.check("photos:u1".into(), quota).await.is_ok());
        assert!(limiter.check("photos:u1".into(), quota).await.is_err());
        assert!(limiter.check("messages:u1".into(), quota).await.is_ok());
    }

    #[tokio::test]
    async fn dice_cuanto_falta_para_reintentar() {
        let limiter = RateLimiter::new();
        let quota = per_minute(1);

        limiter.check("k".into(), quota).await.unwrap();
        let espera = limiter.check("k".into(), quota).await.unwrap_err();
        assert!(espera <= Duration::from_secs(60));
        assert!(espera > Duration::from_secs(58));
    }
}
