//! Direct port of discover.controller.ts.

use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::discover::service::{self, DiscoverError};
use crate::models::Sport;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/discover", get(discover))
}

/// Equivalent of `@Query('sport') sport?: Sport` in discover.controller.ts.
/// `Option<Sport>` means a missing or empty `?sport=` just deserializes to
/// `None` — no sport filter applied, same as the TS version.
#[derive(Debug, Deserialize)]
struct DiscoverQuery {
    sport: Option<Sport>,
}

// Equivalent of `@UseGuards(JwtAuthGuard)` + `@Req() req: AuthenticatedRequest`:
// the `AuthUser` extractor runs before this function's body even starts,
// and rejects the request with 401 on its own if the token is missing/bad.
async fn discover(
    State(state): State<AppState>,
    user: AuthUser,
    Query(params): Query<DiscoverQuery>,
) -> impl IntoResponse {
    match service::discover(&state, &user.user_id, params.sport).await {
        Ok(profiles) => Json(profiles).into_response(),
        Err(DiscoverError::Db(e)) => {
            tracing::error!("discover query failed: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
        Err(DiscoverError::Pool(e)) => {
            tracing::error!("discover pool error: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
    }
}
