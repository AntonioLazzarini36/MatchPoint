//! Direct port of matches.controller.ts.

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde_json::json;

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::matches::service::MatchListItem;
use crate::matches::service::{self, MatchesError};
#[allow(unused_imports)]
use crate::openapi::{ErrorResponse, OkResponse};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/matches", get(list))
        .route("/matches/:matchId", axum::routing::delete(unmatch))
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
        Err(err) => matches_error_response(err),
    }
}

#[utoipa::path(
    delete,
    path = "/matches/{matchId}",
    tag = "matches",
    security(("bearerAuth" = [])),
    params(("matchId" = String, Path, description = "Id del match")),
    responses(
        (status = 200, description = "Match deshecho (y sus mensajes, con él)", body = OkResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres miembro de este match", body = ErrorResponse),
        (status = 404, description = "Match no encontrado", body = ErrorResponse),
    )
)]
async fn unmatch(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
) -> impl IntoResponse {
    match service::unmatch(&state, &match_id, &user.user_id).await {
        Ok(()) => Json(json!({ "ok": true })).into_response(),
        Err(err) => matches_error_response(err),
    }
}

fn matches_error_response(err: MatchesError) -> axum::response::Response {
    let status = match &err {
        MatchesError::NotFound => StatusCode::NOT_FOUND,
        MatchesError::Forbidden => StatusCode::FORBIDDEN,
        MatchesError::Db(_) | MatchesError::Pool(_) | MatchesError::Crypto(_) => {
            tracing::error!("matches error: {err}");
            StatusCode::INTERNAL_SERVER_ERROR
        }
    };
    (status, Json(json!({ "message": err.to_string() }))).into_response()
}
