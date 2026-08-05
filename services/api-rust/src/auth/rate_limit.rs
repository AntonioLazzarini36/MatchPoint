//! Simple in-memory per-IP sliding-window rate limiter for the
//! brute-force/enumeration-prone auth endpoints (`/auth/login`,
//! `/auth/register`, `/auth/email-available`). No new crate dependency:
//! a `Mutex<HashMap<IpAddr, Vec<Instant>>>` is plenty for a single-instance
//! deployment. If this ever runs behind a load balancer with **multiple
//! instances**, this would need to move to a shared store (e.g. Redis) —
//! with N instances the effective limit is N times what it says here.
//!
//! Which IP counts as "the client" depends on `TRUST_PROXY`; see
//! [`client_ip`].

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

use crate::state::AppState;

const WINDOW: Duration = Duration::from_secs(60);
const MAX_REQUESTS_PER_WINDOW: usize = 10;

#[derive(Clone)]
pub struct RateLimiter(Arc<Mutex<HashMap<IpAddr, Vec<Instant>>>>);

impl RateLimiter {
    pub fn new() -> Self {
        let limiter = Self(Arc::new(Mutex::new(HashMap::new())));

        // Periodic sweep so IPs that stop making requests don't sit in the
        // map forever — `check` only prunes the bucket it just touched.
        let background = limiter.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(WINDOW).await;
                let mut buckets = background.0.lock().await;
                let now = Instant::now();
                buckets.retain(|_, hits| {
                    hits.retain(|t| now.duration_since(*t) < WINDOW);
                    !hits.is_empty()
                });
            }
        });

        limiter
    }

    async fn check(&self, ip: IpAddr) -> bool {
        let mut buckets = self.0.lock().await;
        let now = Instant::now();
        let hits = buckets.entry(ip).or_default();
        hits.retain(|t| now.duration_since(*t) < WINDOW);

        if hits.len() >= MAX_REQUESTS_PER_WINDOW {
            false
        } else {
            hits.push(now);
            true
        }
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

pub async fn rate_limit(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    req: Request,
    next: Next,
) -> Response {
    let ip = client_ip(&state, &req, addr);
    if state.rate_limiter.check(ip).await {
        next.run(req).await
    } else {
        (
            StatusCode::TOO_MANY_REQUESTS,
            Json(json!({ "message": "Too many requests, try again later" })),
        )
            .into_response()
    }
}
