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
pub mod schema;
pub mod state;
pub mod swipes;
pub mod users;

use std::sync::Arc;

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
