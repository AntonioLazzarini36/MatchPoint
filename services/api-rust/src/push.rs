//! Notificaciones push (FCM).
//!
//! Hasta ahora la app sólo se enteraba de un mensaje o una propuesta
//! sondeando `/me/notifications` cada 15 s **con la app abierta**. Cerrada,
//! no llegaba nada: te escriben para jugar el sábado y te enteras el lunes.
//! Esto es lo que arregla eso, y no se puede arreglar sólo en el cliente —
//! con la app cerrada no hay cliente ejecutándose.
//!
//! Dos transportes, igual que `mail.rs`:
//!
//! - **FCM**, cuando hay `FIREBASE_SERVICE_ACCOUNT_JSON`. El envío de verdad.
//! - **Log**, cuando no la hay. Escribe la notificación por consola. Así todo
//!   el flujo (registrar dispositivo, disparar el aviso, limpiar tokens
//!   muertos) se desarrolla sin credenciales y sin tocar código.
//!
//! **Por qué una cuenta de servicio y no una "clave de servidor":** Google
//! cerró en 2024 la API antigua de FCM, que iba con una clave fija en una
//! cabecera. La actual (HTTP v1) exige OAuth2, así que hay que firmar un JWT
//! con la clave privada de la cuenta de servicio y canjearlo por un token de
//! acceso. Ese canje se cachea: dura una hora y pedir uno por notificación
//! sería triplicar la latencia de cada envío.

use std::sync::Arc;

use base64::Engine;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::config::AppConfig;

const SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
/// Margen para no usar un token que caduca mientras va por la red.
const TOKEN_SKEW_SECS: i64 = 60;

#[derive(Debug, thiserror::Error)]
pub enum PushError {
    #[error("credenciales de Firebase inválidas: {0}")]
    Credentials(String),
    #[error("no se pudo contactar con FCM: {0}")]
    Transport(String),
    #[error("FCM rechazó el envío ({status}): {body}")]
    Rejected { status: u16, body: String },
}

/// Credenciales sacadas del JSON de la cuenta de servicio.
#[derive(Debug, Deserialize)]
struct ServiceAccount {
    project_id: String,
    client_email: String,
    private_key: String,
    token_uri: String,
}

#[derive(Clone)]
pub enum Pusher {
    /// Sin credenciales: la notificación va al log, no a ningún móvil.
    Log,
    Fcm(Arc<Fcm>),
}

pub struct Fcm {
    account: ServiceAccount,
    client: reqwest::Client,
    /// Token de acceso y cuándo caduca (epoch en segundos).
    cached: RwLock<Option<(String, i64)>>,
}

/// Qué hacer con un token después de intentar enviarle algo.
#[derive(Debug, PartialEq, Eq)]
pub enum Delivery {
    Sent,
    /// El dispositivo ya no existe (app desinstalada, token rotado). Hay que
    /// borrarlo: si no, la tabla se llena de tokens muertos y cada aviso
    /// gasta una petición inútil.
    Stale,
}

impl Pusher {
    pub fn from_config(cfg: &AppConfig) -> Self {
        let Some(raw) = &cfg.firebase_service_account_json else {
            tracing::warn!(
                "push: sin FIREBASE_SERVICE_ACCOUNT_JSON — las notificaciones se escriben en el log, no se envían"
            );
            return Pusher::Log;
        };

        match Self::from_service_account(raw) {
            Ok(pusher) => pusher,
            Err(e) => {
                // No se aborta el arranque: quedarse sin push es molesto, pero
                // dejar la app entera caída es peor. `AppConfig::validate` ya
                // avisa en dev y aborta en producción.
                tracing::error!("push: {e} — se cae al transporte de log");
                Pusher::Log
            }
        }
    }

    /// Construye el transporte real a partir del JSON de la cuenta de
    /// servicio. Separado de `from_config` para poder probarlo sin montar
    /// una `AppConfig` entera (que exige base de datos y secretos).
    pub fn from_service_account(raw: &str) -> Result<Self, PushError> {
        let account = parse_service_account(raw)?;
        tracing::info!("push: usando FCM, proyecto {}", account.project_id);
        Ok(Pusher::Fcm(Arc::new(Fcm {
            account,
            client: reqwest::Client::new(),
            cached: RwLock::new(None),
        })))
    }

    pub async fn send(
        &self,
        token: &str,
        title: &str,
        body: &str,
        data: serde_json::Value,
    ) -> Result<Delivery, PushError> {
        match self {
            Pusher::Log => {
                tracing::info!(
                    "push (log): token {}… título={title:?} cuerpo={body:?} data={data}",
                    token.chars().take(12).collect::<String>()
                );
                Ok(Delivery::Sent)
            }
            Pusher::Fcm(fcm) => fcm.send(token, title, body, data).await,
        }
    }
}

impl Fcm {
    async fn send(
        &self,
        token: &str,
        title: &str,
        body: &str,
        data: serde_json::Value,
    ) -> Result<Delivery, PushError> {
        let access = self.access_token().await?;
        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            self.account.project_id
        );

        let payload = serde_json::json!({
            "message": {
                "token": token,
                "notification": { "title": title, "body": body },
                "data": data,
                // `high` para que Android la entregue aunque el móvil esté en
                // reposo. Con la prioridad normal, Doze puede retrasarla horas
                // — y una notificación de "quedamos en 20 minutos" que llega
                // mañana es peor que no mandarla.
                "android": { "priority": "high" },
            }
        });

        let res = self
            .client
            .post(url)
            .bearer_auth(access)
            .json(&payload)
            .send()
            .await
            .map_err(|e| PushError::Transport(e.to_string()))?;

        let status = res.status();
        if status.is_success() {
            return Ok(Delivery::Sent);
        }

        let text = res.text().await.unwrap_or_default();
        // 404 = UNREGISTERED (app desinstalada o token rotado). 400 con
        // INVALID_ARGUMENT sobre el propio token es lo mismo en la práctica.
        if status.as_u16() == 404 || (status.as_u16() == 400 && text.contains("INVALID_ARGUMENT")) {
            return Ok(Delivery::Stale);
        }

        Err(PushError::Rejected {
            status: status.as_u16(),
            body: text,
        })
    }

    /// Token de acceso de OAuth2, cacheado hasta poco antes de caducar.
    async fn access_token(&self) -> Result<String, PushError> {
        let now = chrono::Utc::now().timestamp();

        if let Some((token, expires_at)) = self.cached.read().await.as_ref() {
            if *expires_at > now + TOKEN_SKEW_SECS {
                return Ok(token.clone());
            }
        }

        let mut guard = self.cached.write().await;
        // Otra tarea puede haberlo renovado mientras esperábamos el lock.
        if let Some((token, expires_at)) = guard.as_ref() {
            if *expires_at > now + TOKEN_SKEW_SECS {
                return Ok(token.clone());
            }
        }

        let (token, expires_in) = self.request_access_token(now).await?;
        *guard = Some((token.clone(), now + expires_in));
        Ok(token)
    }

    async fn request_access_token(&self, now: i64) -> Result<(String, i64), PushError> {
        #[derive(Serialize)]
        struct Claims<'a> {
            iss: &'a str,
            scope: &'a str,
            aud: &'a str,
            iat: i64,
            exp: i64,
        }

        let claims = Claims {
            iss: &self.account.client_email,
            scope: SCOPE,
            aud: &self.account.token_uri,
            iat: now,
            exp: now + 3600,
        };

        let key = jsonwebtoken::EncodingKey::from_rsa_pem(self.account.private_key.as_bytes())
            .map_err(|e| PushError::Credentials(format!("private_key no es un PEM RSA: {e}")))?;
        let assertion = jsonwebtoken::encode(
            &jsonwebtoken::Header::new(jsonwebtoken::Algorithm::RS256),
            &claims,
            &key,
        )
        .map_err(|e| PushError::Credentials(e.to_string()))?;

        #[derive(Deserialize)]
        struct TokenResponse {
            access_token: String,
            expires_in: i64,
        }

        let res = self
            .client
            .post(&self.account.token_uri)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", &assertion),
            ])
            .send()
            .await
            .map_err(|e| PushError::Transport(e.to_string()))?;

        let status = res.status();
        let text = res.text().await.unwrap_or_default();
        if !status.is_success() {
            return Err(PushError::Rejected {
                status: status.as_u16(),
                body: text,
            });
        }

        let parsed: TokenResponse = serde_json::from_str(&text)
            .map_err(|e| PushError::Transport(format!("respuesta de OAuth ilegible: {e}")))?;
        Ok((parsed.access_token, parsed.expires_in))
    }
}

/// Acepta el JSON tal cual **o** en base64.
///
/// El JSON de una cuenta de servicio lleva la clave privada con saltos de
/// línea reales, y en el panel de Railway (y en un `.env`) eso se rompe con
/// facilidad: se pega en varias líneas y la variable se corta en la primera.
/// Permitir base64 da una forma de pegarlo en una sola línea sin sorpresas.
fn parse_service_account(raw: &str) -> Result<ServiceAccount, PushError> {
    let trimmed = raw.trim();
    let json = if trimmed.starts_with('{') {
        trimmed.to_string()
    } else {
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(trimmed)
            .map_err(|e| PushError::Credentials(format!("no es JSON ni base64 válido: {e}")))?;
        String::from_utf8(bytes)
            .map_err(|e| PushError::Credentials(format!("el base64 no contiene texto: {e}")))?
    };

    let mut account: ServiceAccount = serde_json::from_str(&json)
        .map_err(|e| PushError::Credentials(format!("JSON de cuenta de servicio inválido: {e}")))?;

    // Pegado en una variable de entorno, el salto de línea suele llegar
    // escapado (`\n` literal). Sin deshacerlo, el PEM no se puede parsear.
    if account.private_key.contains("\\n") {
        account.private_key = account.private_key.replace("\\n", "\n");
    }

    Ok(account)
}

// --- Envío a un usuario (todos sus dispositivos) ---

/// Avisa a un usuario en segundo plano.
///
/// **No se espera al envío**: una notificación es un efecto secundario del
/// mensaje o de la propuesta, no parte de ellos. Si FCM tarda dos segundos,
/// quien escribió no tiene por qué esperarlos, y si falla tampoco debe
/// convertir en error una petición que ya hizo su trabajo. Por eso esto
/// devuelve inmediatamente y los fallos van al log.
pub fn spawn_notify(
    state: &crate::state::AppState,
    user_id: &str,
    title: String,
    body: String,
    data: serde_json::Value,
) {
    let state = state.clone();
    let user_id = user_id.to_string();
    tokio::spawn(async move {
        if let Err(e) = notify(&state, &user_id, &title, &body, data).await {
            tracing::warn!("push: no se pudo avisar a {user_id}: {e}");
        }
    });
}

async fn notify(
    state: &crate::state::AppState,
    user_id: &str,
    title: &str,
    body: &str,
    data: serde_json::Value,
) -> anyhow::Result<()> {
    use crate::schema::device_tokens;
    use diesel::prelude::*;
    use diesel_async::RunQueryDsl;

    let mut conn = state.db.get().await.map_err(|e| anyhow::anyhow!("{e}"))?;

    let tokens: Vec<String> = device_tokens::table
        .filter(device_tokens::user_id.eq(user_id))
        .select(device_tokens::token)
        .load(&mut conn)
        .await?;

    if tokens.is_empty() {
        return Ok(());
    }

    let mut stale = Vec::new();
    for token in tokens {
        match state.pusher.send(&token, title, body, data.clone()).await {
            Ok(Delivery::Sent) => {}
            Ok(Delivery::Stale) => stale.push(token),
            // Un dispositivo que falla no debe impedir avisar a los demás:
            // puede tener el móvil apagado o el token a medio rotar.
            Err(e) => tracing::warn!("push: fallo enviando a un dispositivo: {e}"),
        }
    }

    if !stale.is_empty() {
        let n = stale.len();
        diesel::delete(device_tokens::table.filter(device_tokens::token.eq_any(stale)))
            .execute(&mut conn)
            .await?;
        tracing::info!("push: {n} token(s) muertos borrados de {user_id}");
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"{
        "project_id": "demo",
        "client_email": "x@demo.iam.gserviceaccount.com",
        "private_key": "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----\n",
        "token_uri": "https://oauth2.googleapis.com/token"
    }"#;

    #[test]
    fn acepta_json_directo() {
        let a = parse_service_account(SAMPLE).unwrap();
        assert_eq!(a.project_id, "demo");
        assert_eq!(a.token_uri, "https://oauth2.googleapis.com/token");
    }

    #[test]
    fn acepta_base64() {
        let encoded = base64::engine::general_purpose::STANDARD.encode(SAMPLE);
        let a = parse_service_account(&encoded).unwrap();
        assert_eq!(a.client_email, "x@demo.iam.gserviceaccount.com");
    }

    /// Es el fallo más probable al pegar el JSON en una variable de entorno:
    /// los saltos de línea de la clave llegan escapados y el PEM no parsea.
    #[test]
    fn deshace_los_saltos_de_linea_escapados() {
        let escaped = SAMPLE.replace("\\n", "\\\\n");
        let a = parse_service_account(&escaped).unwrap();
        assert!(a.private_key.starts_with("-----BEGIN PRIVATE KEY-----\n"));
        assert!(!a.private_key.contains("\\n"));
    }

    #[test]
    fn rechaza_basura() {
        assert!(parse_service_account("no soy nada").is_err());
    }

    /// Comprobación real contra Google, con las credenciales de verdad.
    ///
    /// Está marcada `#[ignore]` porque necesita red y credenciales, y CI no
    /// tiene ninguna de las dos. Para lanzarla:
    ///
    /// ```text
    /// cargo test -- --ignored comprueba_credenciales_contra_google
    /// ```
    ///
    /// Lo que demuestra: que el JWT se firma bien, que Google lo canjea por
    /// un token de acceso y que FCM responde. Se envía a un token inventado
    /// **a propósito** — la respuesta esperada es `Stale`, que sólo se puede
    /// obtener *después* de haberse autenticado correctamente. Si las
    /// credenciales estuvieran mal, fallaría antes con `Rejected` en el
    /// canje, no en el envío.
    #[tokio::test]
    #[ignore = "necesita red y FIREBASE_SERVICE_ACCOUNT_JSON"]
    async fn comprueba_credenciales_contra_google() {
        dotenvy::dotenv().ok();
        let raw = std::env::var("FIREBASE_SERVICE_ACCOUNT_JSON")
            .expect("hace falta FIREBASE_SERVICE_ACCOUNT_JSON (está en .env)");

        let pusher = Pusher::from_service_account(&raw).expect("credenciales ilegibles");
        let res = pusher
            .send(
                "token-inventado-que-no-existe",
                "prueba",
                "prueba",
                serde_json::json!({}),
            )
            .await;

        match res {
            Ok(Delivery::Stale) => {} // autenticado y token rechazado: correcto
            Ok(Delivery::Sent) => panic!("FCM aceptó un token inventado, algo no cuadra"),
            Err(e) => panic!("las credenciales no sirven: {e}"),
        }
    }
}
