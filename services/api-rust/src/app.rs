//! Equivalent of app.module.ts.
//!
//! Nest's `imports: [PrismaModule, DiscoverModule, MeModule, AuthModule,
//! SwipesModule, MatchesModule, ChatsModule, UsersModule]` becomes a plain
//! `.merge()` chain of Axum routers here. Each future module gets its own
//! `src/<module>/mod.rs` exposing a `router() -> Router<AppState>`, exactly
//! like `src/app/controller.rs` does today for the root module.

use axum::Router;

use crate::{auth, chats, users};
use crate::app;
use crate::discover;
use crate::swipes;
use crate::matches;
use crate::me;
use crate::state::AppState;

pub mod controller;
pub mod service;

pub fn build_router(state: AppState) -> Router {
    Router::new()
        .merge(app::controller::router())
        .merge(discover::controller::router())   // next: DiscoverModule
        .merge(me::controller::router())         // next: MeModule
        .merge(auth::controller::router())       // next: AuthModule
        .merge(swipes::controller::router())     // next: SwipesModule
        .merge(matches::controller::router())    // next: MatchesModule
        .merge(chats::controller::router())      // next: ChatsModule
        .merge(users::controller::router())      // next: UsersModule
        .with_state(state)
}
