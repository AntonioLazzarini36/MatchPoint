use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::get, Json, Router};
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::notifications::service;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses
use crate::notifications::service::NotificationCounts;
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/me/notifications", get(counts))
}

#[utoipa::path(
    get,
    path = "/me/notifications",
    tag = "me",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Contadores para los badges de navegación", body = NotificationCounts),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn counts(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::counts(&state, &user.user_id).await {
        Ok(counts) => Json(counts).into_response(),
        Err(err) => {
            tracing::error!("notifications error: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": err.to_string() })),
            )
                .into_response()
        }
    }
}
