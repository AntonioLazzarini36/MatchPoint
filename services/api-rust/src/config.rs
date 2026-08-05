//! Equivalent of `ConfigModule.forRoot({ isGlobal: true })` in app.module.ts,
//! plus the env-reading helpers scattered through auth.service.ts.
//! Loaded once at startup and shared via `AppState`.

use std::env;

/// En qué tipo de entorno corre el proceso. Cambia de "avisa" a "no
/// arranques" en las comprobaciones de abajo: en dev conviene que la app
/// levante aunque falte algo, en producción un secreto de ejemplo o un
/// CORS abierto son un agujero, no una molestia.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppEnv {
    Development,
    Production,
}

impl AppEnv {
    pub fn is_production(self) -> bool {
        self == AppEnv::Production
    }
}

/// Secretos de ejemplo que viven en `.env`/`docker-compose.yml` para que
/// clonar el repo y arrancar funcione sin configurar nada. Justo por eso
/// son públicos, y por eso el proceso se niega a arrancar con ellos en
/// producción: cualquiera que lea el repo podría firmar tokens válidos.
const DEV_SECRETS: &[&str] = &[
    "dev_access_secret_change_me",
    "dev_refresh_secret_change_me",
    "1mKQdNgaRWyt/45tyC5TKw9ogvCE45Kq5p+wciokGtg=",
];

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub env: AppEnv,
    pub port: u16,
    pub database_url: String,

    pub jwt_access_secret: String,
    pub jwt_refresh_secret: String,
    pub jwt_access_expires_in_seconds: i64,
    pub jwt_refresh_expires_in_seconds: i64,

    pub message_key_base64: String,

    /// Directorio local donde se guardan las fotos subidas. Servido por
    /// tanto tower-http (`ServeDir`) como escrito por `me::service::upload_photo`.
    pub photos_dir: String,
    /// Base pública usada para construir la URL absoluta de cada foto
    /// (`{public_base_url}/uploads/{archivo}`). En dev es `http://localhost:{port}`;
    /// en un despliegue real habría que apuntarlo al dominio/proxy público.
    pub public_base_url: String,

    /// Orígenes permitidos por CORS.
    ///
    /// Vacío = permitir cualquiera: cómodo en dev (Flutter web arranca en un
    /// puerto distinto cada vez) y rechazado en producción.
    ///
    /// `CORS_ALLOWED_ORIGINS=none` = **ningún** origen de navegador. Es la
    /// opción correcta mientras sólo exista la app móvil: CORS es una regla
    /// que aplican los navegadores, y una app nativa no pasa por ella. Sin
    /// esta opción, arrancar en producción sin frontend web obligaba a
    /// inventarse una URL para rellenar el hueco, que no permite nada real
    /// y encima aparenta significar algo.
    pub cors_allowed_origins: Vec<String>,

    /// Si `CORS_ALLOWED_ORIGINS` se llegó a poner, aunque fuera a `none`.
    /// Hace falta aparte de la lista porque "sin declarar" y "declarado
    /// como ninguno" acaban las dos en una lista vacía, pero una es un
    /// descuido y la otra una decisión.
    pub cors_declared: bool,

    /// Si hay un proxy/balanceador delante en el que se puede confiar.
    ///
    /// Importa para el rate limiter: sin esto ve la IP de la conexión TCP,
    /// que detrás de un proxy es la del proxy **para todo el mundo** — el
    /// límite dejaría de ser por cliente y un solo atacante bloquearía los
    /// intentos de login de todos. Con esto lee `X-Forwarded-For`.
    ///
    /// Es opt-in a propósito: esa cabecera la pone quien llama, así que
    /// confiar en ella *sin* un proxy delante permitiría saltarse el
    /// límite inventando una IP distinta en cada intento.
    pub trust_proxy: bool,

    /// API key de Resend. `None` = los correos se escriben en el log en
    /// vez de enviarse (ver `mail::Mailer`), que es lo que permite
    /// desarrollar el flujo de verificacion sin credenciales.
    /// Aplicar migraciones pendientes al arrancar. Por defecto sí: es lo
    /// que hace que un despliegue funcione sin entrar por consola. Se puede
    /// desactivar si algún día las migraciones pasan a ser un paso propio
    /// del pipeline (ver `migrate.rs`).
    pub run_migrations: bool,

    pub resend_api_key: Option<String>,
    /// Remitente de los correos. Sin dominio verificado en Resend, tiene
    /// que ser `onboarding@resend.dev` y solo se puede enviar al email con
    /// el que se creo la cuenta de Resend.
    pub email_from: String,
}

/// Quita de la URL de conexion los parametros que libpq no entiende.
///
/// El caso real: `?schema=public`. Es un invento de Prisma — lo lleva el
/// `.env.example` heredado del backend NestJS viejo — y libpq lo rechaza
/// con `invalid URI query parameter: "schema"`, un error que no dice de
/// donde sale ni que el resto de la URL estaba bien.
///
/// Se descarta en vez de fallar porque `schema=public` no pide nada
/// distinto de lo que ya hace Postgres por defecto: quitarlo no cambia a
/// que base te conectas. Cualquier otro parametro se respeta tal cual
/// (`sslmode`, `connect_timeout`...), que si tienen efecto.
fn sanitize_database_url(raw: &str) -> String {
    const UNSUPPORTED: &[&str] = &["schema"];

    let Some((base, query)) = raw.split_once('?') else {
        return raw.to_string();
    };

    let mut dropped: Vec<&str> = Vec::new();
    let kept: Vec<&str> = query
        .split('&')
        .filter(|param| {
            let key = param.split('=').next().unwrap_or_default();
            if UNSUPPORTED.contains(&key) {
                dropped.push(key);
                false
            } else {
                true
            }
        })
        .collect();

    if dropped.is_empty() {
        return raw.to_string();
    }

    // Por log y no en silencio: si alguien puso el parametro esperando que
    // hiciera algo, tiene que enterarse de que no lo hace.
    eprintln!(
        "DATABASE_URL: ignorando parametro(s) que Postgres no acepta: {}",
        dropped.join(", ")
    );

    if kept.is_empty() {
        base.to_string()
    } else {
        format!("{base}?{}", kept.join("&"))
    }
}

/// El host de una URL de conexion de Postgres, sin credenciales ni puerto.
/// Devuelve `None` si no se puede leer — en ese caso no hay nada que
/// avisar, ya fallara al conectar con su propio error.
fn database_host(url: &str) -> Option<String> {
    let after_scheme = url.split("://").nth(1)?;
    let authority = after_scheme.split('/').next()?;
    // Lo de despues de la ultima `@` para saltarse usuario:contrasena, que
    // pueden contener `@` a su vez.
    let host_port = authority.rsplit('@').next()?;
    let host = host_port.split(':').next()?;
    if host.is_empty() {
        None
    } else {
        Some(host.to_lowercase())
    }
}

/// Lee una duracion en **segundos**, como numero pelado.
///
/// Aborta si el valor esta puesto pero no se puede leer. Antes se caia
/// silenciosamente al valor por defecto, asi que escribir `900s` o `15m`
/// (los formatos del backend NestJS viejo, que aun asoman en algun `.env`
/// antiguo) se ignoraba sin decir nada y la sesion duraba lo que el codigo
/// quisiera, no lo que ponia la config. Una config que miente es peor que
/// una que no arranca.
fn seconds_from_env(name: &str, default: i64) -> i64 {
    match env::var(name) {
        Err(_) => default,
        Ok(raw) => raw.trim().parse().unwrap_or_else(|_| {
            panic!(
                "{name}={raw:?} no es valido: tiene que ser un numero de segundos, sin sufijo (por ejemplo 900, no \"900s\" ni \"15m\")"
            )
        }),
    }
}

impl AppConfig {
    /// Reads all env vars once. Panics on startup if something required
    /// is missing, same spirit as Nest failing fast on bad config.
    pub fn from_env() -> Self {
        // Load .env if present (equivalent of `import 'dotenv/config'` in main.ts)
        dotenvy::dotenv().ok();

        let env_name = env::var("APP_ENV").unwrap_or_else(|_| "development".to_string());
        let app_env = match env_name.to_lowercase().as_str() {
            "production" | "prod" => AppEnv::Production,
            _ => AppEnv::Development,
        };

        let port = env::var("PORT")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(3000);

        // Las obligatorias se leen todas juntas y se reportan juntas. Con un
        // `expect` por variable, cada despliegue moria en la primera que
        // faltara: arreglabas esa, volvias a desplegar (minutos de build) y
        // te encontrabas la siguiente. Con la lista completa se arregla en
        // una sola vuelta.
        //
        // Sin valor por defecto a proposito: un secreto JWT que cayera
        // silenciosamente a un valor conocido dejaria a cualquiera firmar
        // tokens validos en el entorno que se olvidara de ponerlo.
        let mut missing: Vec<&str> = Vec::new();
        let mut required = |name: &'static str| -> String {
            match env::var(name) {
                Ok(value) if !value.trim().is_empty() => value,
                _ => {
                    missing.push(name);
                    String::new()
                }
            }
        };

        let database_url = sanitize_database_url(&required("DATABASE_URL"));
        let jwt_access_secret = required("JWT_ACCESS_SECRET");
        let jwt_refresh_secret = required("JWT_REFRESH_SECRET");
        let message_key_base64 = required("MESSAGE_KEY_BASE64");

        if !missing.is_empty() {
            panic!(
                "faltan {} variable(s) de entorno obligatoria(s): {}.                  Ver services/api-rust/DEPLOY.md",
                missing.len(),
                missing.join(", ")
            );
        }

        // 15 min y 30 dias, mismos valores por defecto que auth.service.ts.
        let jwt_access_expires_in_seconds = seconds_from_env("JWT_ACCESS_EXPIRES_IN_SECONDS", 900);
        let jwt_refresh_expires_in_seconds =
            seconds_from_env("JWT_REFRESH_EXPIRES_IN_SECONDS", 2_592_000);

        let photos_dir = env::var("PHOTOS_DIR").unwrap_or_else(|_| "./uploads".to_string());
        let public_base_url =
            env::var("PUBLIC_BASE_URL").unwrap_or_else(|_| format!("http://localhost:{port}"));

        let cors_raw = env::var("CORS_ALLOWED_ORIGINS").unwrap_or_default();
        let cors_declared = !cors_raw.trim().is_empty();
        let cors_allowed_origins: Vec<String> = if cors_raw.trim().eq_ignore_ascii_case("none") {
            Vec::new()
        } else {
            cors_raw
                .split(',')
                .map(|o| o.trim().to_string())
                .filter(|o| !o.is_empty())
                .collect()
        };

        let trust_proxy = env::var("TRUST_PROXY")
            .map(|v| matches!(v.to_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false);

        let run_migrations = env::var("RUN_MIGRATIONS")
            .map(|v| !matches!(v.to_lowercase().as_str(), "0" | "false" | "no"))
            .unwrap_or(true);

        let resend_api_key = env::var("RESEND_API_KEY").ok().filter(|k| !k.is_empty());
        let email_from = env::var("EMAIL_FROM")
            .unwrap_or_else(|_| "MatchPoint <onboarding@resend.dev>".to_string());

        let cfg = Self {
            env: app_env,
            port,
            database_url,
            jwt_access_secret,
            jwt_refresh_secret,
            jwt_access_expires_in_seconds,
            jwt_refresh_expires_in_seconds,
            message_key_base64,
            photos_dir,
            public_base_url,
            cors_allowed_origins,
            cors_declared,
            trust_proxy,
            run_migrations,
            resend_api_key,
            email_from,
        };

        cfg.validate();
        cfg
    }

    /// Comprueba lo que en dev es una molestia y en producción un agujero.
    ///
    /// En desarrollo sólo avisa por log: la gracia de clonar el repo y
    /// hacer `cargo run` es que funcione sin configurar nada. En producción
    /// aborta el arranque, porque un fallo ruidoso al desplegar es muchísimo
    /// mejor que un servicio en pie con secretos públicos.
    fn validate(&self) {
        let mut problems: Vec<String> = Vec::new();

        for (name, value) in [
            ("JWT_ACCESS_SECRET", &self.jwt_access_secret),
            ("JWT_REFRESH_SECRET", &self.jwt_refresh_secret),
            ("MESSAGE_KEY_BASE64", &self.message_key_base64),
        ] {
            if DEV_SECRETS.contains(&value.as_str()) {
                problems.push(format!(
                    "{name} sigue siendo el valor de ejemplo del repo, que es público"
                ));
            }
        }

        if self.jwt_access_secret.len() < 32 || self.jwt_refresh_secret.len() < 32 {
            problems.push("los secretos JWT deberían tener al menos 32 caracteres".to_string());
        }

        if !self.cors_declared {
            problems.push(
                "CORS_ALLOWED_ORIGINS sin poner: se permitiría cualquier origen. Pon la URL de tu web, o `none` si de momento sólo existe la app móvil"
                    .to_string(),
            );
        }

        if self.resend_api_key.is_none() {
            problems.push(
                "RESEND_API_KEY sin poner: los correos de verificacion se escriben en el log en vez de enviarse"
                    .to_string(),
            );
        }

        // Un host que sólo resuelve en la máquina de desarrollo: `db` es el
        // nombre del servicio en docker-compose y `localhost` es el propio
        // contenedor. Pegar esa URL en el panel del proveedor es el error
        // más fácil de cometer, y sin esto no se ve hasta que fallan las
        // migraciones con un "could not translate host name" que no dice de
        // dónde ha salido ese nombre.
        if let Some(host) = database_host(&self.database_url) {
            if matches!(host.as_str(), "db" | "localhost" | "127.0.0.1" | "::1") {
                problems.push(format!(
                    "DATABASE_URL apunta a {host:?}, que sólo existe en tu máquina.                      Usa la URL que te da el proveedor de la base de datos"
                ));
            }
        }

        if self.public_base_url.starts_with("http://localhost") {
            problems.push(format!(
                "PUBLIC_BASE_URL es {} — las URLs de las fotos apuntarían al dispositivo de cada usuario, no al servidor",
                self.public_base_url
            ));
        }

        if problems.is_empty() {
            return;
        }

        if self.env.is_production() {
            for problem in &problems {
                tracing::error!("config inválida en producción: {problem}");
            }
            panic!(
                "APP_ENV=production con {} problema(s) de configuración — ver los logs de arriba",
                problems.len()
            );
        }

        for problem in &problems {
            tracing::warn!("config de desarrollo: {problem}");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::sanitize_database_url;

    /// El caso real que rompía el despliegue: `?schema=public` viene del
    /// `.env.example` heredado de Prisma y libpq lo rechaza entero.
    #[test]
    fn drops_prisma_schema_param() {
        assert_eq!(
            sanitize_database_url("postgresql://u:p@host:5432/db?schema=public"),
            "postgresql://u:p@host:5432/db"
        );
    }

    /// Los parámetros que sí hacen algo tienen que sobrevivir — `sslmode`
    /// es obligatorio en varios proveedores gestionados.
    #[test]
    fn keeps_supported_params() {
        assert_eq!(
            sanitize_database_url("postgresql://u:p@host/db?sslmode=require"),
            "postgresql://u:p@host/db".to_string() + "?sslmode=require"
        );
        assert_eq!(
            sanitize_database_url("postgresql://u:p@host/db?schema=public&sslmode=require"),
            "postgresql://u:p@host/db?sslmode=require"
        );
    }

    /// Sin query no se toca nada, ni se añade un `?` de más.
    #[test]
    fn leaves_plain_urls_alone() {
        let url = "postgresql://u:p@host:5432/db";
        assert_eq!(sanitize_database_url(url), url);
    }

    /// El host se saca saltando credenciales y puerto. `db` como host es
    /// el nombre del servicio de docker-compose — justo el que no vale
    /// fuera de la máquina de desarrollo. Ojo: también aparece como
    /// *nombre de base de datos* al final de la URL, y eso sí es normal.
    #[test]
    fn extracts_host() {
        use super::database_host;
        assert_eq!(
            database_host("postgresql://matchpoint:matchpoint@db:5432/matchpoint"),
            Some("db".to_string())
        );
        assert_eq!(
            database_host("postgresql://u:p@containers-us-west-1.railway.app:7432/railway"),
            Some("containers-us-west-1.railway.app".to_string())
        );
        // Contrasena con `@` dentro: el host es lo que va tras la ultima.
        assert_eq!(
            database_host("postgresql://user:pa@ss@real-host:5432/db"),
            Some("real-host".to_string())
        );
        // `db` como nombre de base de datos, no como host: no debe saltar.
        assert_eq!(
            database_host("postgresql://u:p@postgres.railway.internal:5432/db"),
            Some("postgres.railway.internal".to_string())
        );
        assert_eq!(database_host("no-es-una-url"), None);
    }
}
