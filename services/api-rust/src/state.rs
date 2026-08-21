//! What Nest gives you for free via dependency injection (any service can
//! ask for `PrismaService` or `ConfigService` in its constructor), Axum
//! needs made explicit: one `AppState` struct, cloned cheaply (it's just
//! two Arcs under the hood) into every handler that needs it.

use std::sync::Arc;

use crate::auth::rate_limit::RateLimiter;
use crate::config::AppConfig;
use crate::db::DbPool;
use crate::mail::Mailer;
use crate::push::Pusher;

#[derive(Clone)]
pub struct AppState {
    pub db: DbPool,
    pub config: Arc<AppConfig>,
    pub rate_limiter: RateLimiter,
    pub mailer: Mailer,
    pub pusher: Pusher,
}
