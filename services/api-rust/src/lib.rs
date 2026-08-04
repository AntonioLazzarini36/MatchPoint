//! Library root. Holds all app modules so they're part of the `matchpoint_api`
//! *library* target, not just the binary. This matters for `cargo clippy
//! --all-targets`: the test-target compilation of a pure bin crate only
//! treats items reachable from `main`/`#[test]` as "used", which false-flagged
//! Message/Swipe/User/etc as dead_code even though the real app uses them
//! via routes/services. As part of a lib target, pub items are considered
//! part of the crate's public surface and are exempt from that check.

pub mod app;
pub mod auth;
pub mod chats;
pub mod config;
pub mod db;
pub mod discover;
pub mod matches;
pub mod me;
pub mod models;
pub mod notifications;
pub mod openapi;
pub mod proposals;
pub mod schema;
pub mod state;
pub mod swipes;
pub mod users;

use std::sync::Arc;

use axum::extract::DefaultBodyLimit;
use tower_http::cors::{Any, CorsLayer};
use tracing_subscriber::EnvFilter;

use config::AppConfig;
use state::AppState;

/// Boots and runs the HTTP server. Called from `main.rs`.
pub async fn run() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("info".parse().unwrap()))
        .init();

    let cfg = AppConfig::from_env();
    let port = cfg.port;

    std::fs::create_dir_all(&cfg.photos_dir)
        .unwrap_or_else(|e| panic!("failed to create photos_dir {:?}: {e}", cfg.photos_dir));

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
        rate_limiter: auth::rate_limit::RateLimiter::new(),
    };

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // axum's extractors default to a 2MB body limit; photos go up to 5MB
    // (see me::photos::MAX_PHOTO_BYTES), so raise the ceiling app-wide.
    let router = app::build_router(state)
        .layer(cors)
        .layer(DefaultBodyLimit::max(8 * 1024 * 1024));

    let addr = format!("0.0.0.0:{port}");
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| panic!("failed to bind {addr}: {e}"));

    tracing::info!("listening on {addr}");

    axum::serve(
        listener,
        router.into_make_service_with_connect_info::<std::net::SocketAddr>(),
    )
    .await
    .expect("server crashed");
}
