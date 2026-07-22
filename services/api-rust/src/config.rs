//! Equivalent of `ConfigModule.forRoot({ isGlobal: true })` in app.module.ts,
//! plus the env-reading helpers scattered through auth.service.ts.
//! Loaded once at startup and shared via `AppState`.

use std::env;

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub port: u16,
    pub database_url: String,

    pub jwt_access_secret: String,
    pub jwt_refresh_secret: String,
    pub jwt_access_expires_in_seconds: i64,
    pub jwt_refresh_expires_in_seconds: i64,

    pub message_key_base64: String,
}

impl AppConfig {
    /// Reads all env vars once. Panics on startup if something required
    /// is missing, same spirit as Nest failing fast on bad config.
    pub fn from_env() -> Self {
        // Load .env if present (equivalent of `import 'dotenv/config'` in main.ts)
        dotenvy::dotenv().ok();

        let port = env::var("PORT")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(3000);

        let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

        // Mirrors the `?? 'dev_access_secret'` fallbacks in auth.service.ts.
        // Fine for local dev, but you should override these in every real env.
        let jwt_access_secret =
            env::var("JWT_ACCESS_SECRET").unwrap_or_else(|_| "dev_access_secret".to_string());
        let jwt_refresh_secret =
            env::var("JWT_REFRESH_SECRET").unwrap_or_else(|_| "dev_refresh_secret".to_string());

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

        Self {
            port,
            database_url,
            jwt_access_secret,
            jwt_refresh_secret,
            jwt_access_expires_in_seconds,
            jwt_refresh_expires_in_seconds,
            message_key_base64,
        }
    }
}
