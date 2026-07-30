//! Direct port of matches.controller.ts.

use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::get, Json, Router};
use serde_json::json;

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::matches::service::MatchListItem;
use crate::matches::service::{self, MatchesError};
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/matches", get(list))
}

#[utoipa::path(
    get,
    path = "/matches",
    tag = "matches",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Matches del usuario autenticado", body = Vec<MatchListItem>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn list(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::list(&state, &user.user_id).await {
        Ok(matches) => Json(matches).into_response(),
        Err(MatchesError::Db(e)) => {
            tracing::error!("matches query failed: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
        Err(MatchesError::Pool(e)) => {
            tracing::error!("matches pool error: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
    }
}
