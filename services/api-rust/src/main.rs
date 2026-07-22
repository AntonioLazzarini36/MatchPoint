//! Direct port of main.ts.
//!
//! Notable carry-over from status.md: the Nest version had to bind to
//! `0.0.0.0` explicitly (not just the default port) for the API to answer
//! requests from the Flutter emulator. We do the same here from day one.

mod app;
mod config;
mod db;
mod state;
mod schema;
mod models;
mod auth;
mod discover;
mod me;
mod swipes;
mod matches;
mod users;
mod chats;

use std::sync::Arc;

use tower_http::cors::{Any, CorsLayer};
use tracing_subscriber::EnvFilter;

use config::AppConfig;
use state::AppState;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("info".parse().unwrap()))
        .init();

    let cfg = AppConfig::from_env();
    let port = cfg.port;

    let pool = db::build_pool(&cfg.database_url).await;

    {
        use diesel_async::RunQueryDsl;
        tracing::info!("checking database connectivity...");
        let check = tokio::time::timeout(std::time::Duration::from_secs(5), async {
            let mut conn = match pool.get().await {
                Ok(c) => c,
                Err(e) => return Err(format!("pool.get() failed: {e}")),
            };
            diesel::sql_query("SELECT 1")
                .execute(&mut conn)
                .await
                .map_err(|e| format!("query failed: {e}"))
        })
            .await;

        match check {
            Ok(Ok(_)) => tracing::info!("database connectivity OK"),
            Ok(Err(e)) => tracing::error!("{e}"),
            Err(_) => tracing::error!(
                "database connection TIMED OUT after 5s — pool.get() never returned"
            ),
        }
    }

    let state = AppState {
        db: pool,
        config: Arc::new(cfg),
    };

    // Equivalent of `app.enableCors({ origin: true, credentials: true, ... })`.
    // NOTE: Nest's `origin: true` reflects the caller's Origin header, which
    // is only valid together with credentials because it's not a wildcard.
    // Axum's CORS layer forces an explicit choice here; `Any` below matches
    // the *permissiveness* of the Nest config but drops credentialed
    // cookies support (Any + Any is what tower-http allows since it can't
    // reflect the origin dynamically without a callback). If the mobile
    // app is not relying on cookies (it should be sending the JWT via the
    // Authorization header, per jwt.strategy.ts), this is a safe swap.
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let router = app::build_router(state).layer(cors);

    let addr = format!("0.0.0.0:{port}");
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("failed to bind {addr}: {e}"));

    tracing::info!("listening on {addr}");

    axum::serve(listener, router.into_make_service())
        .await
        .expect("server crashed");
}
