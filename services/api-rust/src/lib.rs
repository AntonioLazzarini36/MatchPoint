//! Library root. Holds all app modules so they're part of the `matchpoint_api`
//! *library* target, not just the binary. This matters for `cargo clippy
//! --all-targets`: the test-target compilation of a pure bin crate only
//! treats items reachable from `main`/`#[test]` as "used", which false-flagged
//! Message/Swipe/User/etc as dead_code even though the real app uses them
//! via routes/services. As part of a lib target, pub items are considered
//! part of the crate's public surface and are exempt from that check.

pub mod admin;
pub mod app;
pub mod auth;
pub mod chats;
pub mod config;
pub mod db;
pub mod discover;
pub mod mail;
pub mod matches;
pub mod me;
pub mod migrate;
pub mod models;
pub mod notifications;
pub mod openapi;
pub mod proposals;
pub mod push;
pub mod schema;
pub mod state;
pub mod swipes;
pub mod users;

use std::sync::Arc;

use axum::extract::DefaultBodyLimit;
use axum::http::HeaderValue;
use tower_http::cors::{Any, CorsLayer};
use tracing_subscriber::EnvFilter;

use config::AppConfig;
use state::AppState;

/// Abre el socket de escucha aceptando IPv6 **e** IPv4 a la vez.
///
/// Hacen falta las dos cosas por motivos distintos:
/// - **IPv6**: la red privada de Railway es sólo IPv6, así que un proceso
///   atado nada más a `0.0.0.0` está vivo pero donde nadie le habla — y
///   el síntoma es un "healthcheck failure" sin ningún error en el log.
/// - **IPv4**: es por donde entra todo en desarrollo (`127.0.0.1:3000`, y
///   el `adb reverse` que usa el móvil por cable).
///
/// `TcpListener::bind("[::]:puerto")` a secas no sirve: en Linux funciona
/// porque `bindv6only` viene desactivado, pero **en Windows viene activado**
/// y el socket rechaza IPv4 en silencio. De ahí montar el socket a mano
/// para apagar ese flag explícitamente.
///
/// Si el sistema no tiene IPv6, se cae a IPv4 a secas.
async fn bind_dual_stack(port: u16) -> tokio::net::TcpListener {
    use socket2::{Domain, Protocol, Socket, Type};

    let build = || -> std::io::Result<tokio::net::TcpListener> {
        let addr: std::net::SocketAddr = format!("[::]:{port}").parse().expect("addr valida");
        let socket = Socket::new(Domain::IPV6, Type::STREAM, Some(Protocol::TCP))?;
        socket.set_only_v6(false)?;
        socket.set_nonblocking(true)?;
        socket.bind(&addr.into())?;
        socket.listen(1024)?;
        tokio::net::TcpListener::from_std(std::net::TcpListener::from(socket))
    };

    match build() {
        Ok(listener) => {
            tracing::info!("listening on [::]:{port} (IPv6 + IPv4)");
            listener
        }
        Err(e) => {
            tracing::warn!("sin IPv6 utilizable ({e}); escuchando sólo en IPv4");
            let addr = format!("0.0.0.0:{port}");
            tokio::net::TcpListener::bind(&addr)
                .await
                .unwrap_or_else(|e| panic!("failed to bind {addr}: {e}"))
        }
    }
}

/// Boots and runs the HTTP server. Called from `main.rs`.
pub async fn run() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("info".parse().unwrap()))
        .init();

    let cfg = AppConfig::from_env();
    let port = cfg.port;

    std::fs::create_dir_all(&cfg.photos_dir)
        .unwrap_or_else(|e| panic!("failed to create photos_dir {:?}: {e}", cfg.photos_dir));

    // Antes del pool: si el esquema no está al día, no tiene sentido
    // abrir conexiones para consultarlo. Es bloqueante (Diesel síncrono),
    // así que va en un hilo aparte para no parar el executor.
    if cfg.run_migrations {
        let database_url = cfg.database_url.clone();
        tokio::task::spawn_blocking(move || migrate::run(&database_url))
            .await
            .expect("migraciones: el hilo falló");
    } else {
        tracing::warn!("migraciones desactivadas por RUN_MIGRATIONS=false");
    }

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

    let cfg_for_services = cfg.clone();
    let state = AppState {
        db: pool,
        config: Arc::new(cfg),
        rate_limiter: auth::rate_limit::RateLimiter::new(),
        mailer: mail::Mailer::from_config(&cfg_for_services),
        pusher: push::Pusher::from_config(&cfg_for_services),
    };

    // Con la lista vacía se permite cualquier origen, que es lo comodo en
    // dev (Flutter web arranca en un puerto distinto cada vez). En
    // produccion `AppConfig::validate` no deja arrancar asi.
    //
    // El riesgo real de CORS abierto aqui es bajo porque la auth va por
    // Bearer token y no por cookies — un origen ajeno no puede robar el
    // token del navegador — pero no hay motivo para dejarlo abierto una
    // vez se sabe desde donde se va a usar.
    let origins = &state.config.cors_allowed_origins;
    let cors = if origins.is_empty() && !state.config.cors_declared {
        // Sin declarar: cualquiera. `AppConfig::validate` no deja llegar
        // aqui en produccion.
        CorsLayer::new()
            .allow_origin(Any)
            .allow_methods(Any)
            .allow_headers(Any)
    } else if origins.is_empty() {
        // Declarado como `none`: ningun origen de navegador. La app movil
        // no se ve afectada, CORS solo lo aplican los navegadores.
        tracing::info!("CORS: ningun origen de navegador permitido (none)");
        CorsLayer::new()
    } else {
        let parsed: Vec<HeaderValue> = origins
            .iter()
            .map(|o| {
                o.parse::<HeaderValue>()
                    .unwrap_or_else(|e| panic!("CORS_ALLOWED_ORIGINS: {o:?} invalido: {e}"))
            })
            .collect();
        tracing::info!("CORS restringido a {origins:?}");
        CorsLayer::new()
            .allow_origin(parsed)
            .allow_methods(Any)
            .allow_headers(Any)
    };

    // axum's extractors default to a 2MB body limit; photos go up to 5MB
    // (see me::photos::MAX_PHOTO_BYTES), so raise the ceiling app-wide.
    let router = app::build_router(state)
        .layer(cors)
        .layer(DefaultBodyLimit::max(8 * 1024 * 1024));

    let listener = bind_dual_stack(port).await;

    axum::serve(
        listener,
        router.into_make_service_with_connect_info::<std::net::SocketAddr>(),
    )
    .await
    .expect("server crashed");
}
