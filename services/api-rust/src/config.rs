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

    /// Orígenes permitidos por CORS. Vacío = permitir cualquiera, que es
    /// lo cómodo en dev (Flutter web arranca en un puerto distinto cada
    /// vez) y lo que **no** se permite en producción.
    pub cors_allowed_origins: Vec<String>,

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

        let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

        // No fallback: a silently-defaulted JWT secret would let anyone forge
        // valid access/refresh tokens in any env that forgot to set these.
        let jwt_access_secret =
            env::var("JWT_ACCESS_SECRET").expect("JWT_ACCESS_SECRET must be set");
        let jwt_refresh_secret =
            env::var("JWT_REFRESH_SECRET").expect("JWT_REFRESH_SECRET must be set");

        let jwt_access_expires_in_seconds = env::var("JWT_ACCESS_EXPIRES_IN_SECONDS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(900); // 15 min, same default as auth.service.ts

        let jwt_refresh_expires_in_seconds = env::var("JWT_REFRESH_EXPIRES_IN_SECONDS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(2_592_000); // 30 days, same default as auth.service.ts

        let message_key_base64 = env::var("MESSAGE_KEY_BASE64")
            .expect("MESSAGE_KEY_BASE64 must be set (used by chats/crypto)");

        let photos_dir = env::var("PHOTOS_DIR").unwrap_or_else(|_| "./uploads".to_string());
        let public_base_url =
            env::var("PUBLIC_BASE_URL").unwrap_or_else(|_| format!("http://localhost:{port}"));

        let cors_allowed_origins: Vec<String> = env::var("CORS_ALLOWED_ORIGINS")
            .unwrap_or_default()
            .split(',')
            .map(|o| o.trim().to_string())
            .filter(|o| !o.is_empty())
            .collect();

        let trust_proxy = env::var("TRUST_PROXY")
            .map(|v| matches!(v.to_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false);

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
            trust_proxy,
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

        if self.cors_allowed_origins.is_empty() {
            problems.push("CORS_ALLOWED_ORIGINS vacío: se permite cualquier origen".to_string());
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
