//! Equivalent of app.module.ts.
//!
//! Nest's `imports: [PrismaModule, DiscoverModule, MeModule, AuthModule,
//! SwipesModule, MatchesModule, ChatsModule, UsersModule]` becomes a plain
//! `.merge()` chain of Axum routers here. Each future module gets its own
//! `src/<module>/mod.rs` exposing a `router() -> Router<AppState>`, exactly
//! like `src/app/controller.rs` does today for the root module.

use axum::Router;
use tower_http::services::ServeDir;
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use crate::app;
use crate::discover;
use crate::matches;
use crate::me;
use crate::notifications;
use crate::openapi::ApiDoc;
use crate::proposals;
use crate::state::AppState;
use crate::swipes;
use crate::{auth, chats, users};

pub mod controller;
pub mod service;

pub fn build_router(state: AppState) -> Router {
    let photos_dir = state.config.photos_dir.clone();

    Router::new()
        .merge(app::controller::router())
        .merge(discover::controller::router()) // next: DiscoverModule
        .merge(me::controller::router(state.clone())) // next: MeModule
        .merge(auth::controller::router(state.clone())) // next: AuthModule
        .merge(swipes::controller::router(state.clone())) // next: SwipesModule
        .merge(matches::controller::router()) // next: MatchesModule
        .merge(proposals::controller::router())
        .merge(notifications::controller::router())
        .merge(chats::controller::router(state.clone())) // next: ChatsModule
        .merge(users::controller::router(state.clone())) // next: UsersModule
        .merge(SwaggerUi::new("/docs").url("/api-docs/openapi.json", ApiDoc::openapi()))
        .nest_service("/uploads", ServeDir::new(photos_dir))
        .with_state(state)
}
