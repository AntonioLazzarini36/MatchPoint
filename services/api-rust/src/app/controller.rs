//! Direct port of app.controller.ts.
//!
//! Nest wires `@Controller() -> @Get()` decorators; Axum wires plain
//! functions into a `Router`. `router()` here is the Rust equivalent of
//! the `@Controller()` class itself - every other module (auth, discover,
//! swipes...) will get its own `controller.rs` with the same shape, and
//! `app.rs` merges them the way `app.module.ts` lists them in `imports`.

use axum::{routing::get, Json, Router};
use serde_json::{json, Value};

use crate::app::service;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(get_hello))
        .route("/health", get(health))
}

async fn get_hello() -> &'static str {
    service::get_hello()
}

async fn health() -> Json<Value> {
    Json(json!({ "ok": true }))
}
