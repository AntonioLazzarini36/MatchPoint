//! Direct port of users.controller.ts.

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
use crate::discover::service::DiscoverProfile;
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;
use crate::users::service::{self, UsersError};

pub fn router() -> Router<AppState> {
    Router::new().route("/users/:userId/profile", get(get_profile))
}

#[utoipa::path(
    get,
    path = "/users/{userId}/profile",
    tag = "users",
    security(("bearerAuth" = [])),
    params(("userId" = String, Path, description = "Id del usuario")),
    responses(
        (status = 200, description = "Perfil público del usuario", body = DiscoverProfile),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 404, description = "Perfil no encontrado", body = ErrorResponse),
    )
)]
async fn get_profile(
    State(state): State<AppState>,
    _user: AuthUser, // guard exige token, pero no se usa el resultado
    Path(user_id): Path<String>,
) -> impl IntoResponse {
    match service::get_profile(&state, &user_id).await {
        Ok(profile) => Json(profile).into_response(),
        Err(UsersError::ProfileNotFound) => (
            StatusCode::NOT_FOUND,
            Json(json!({ "message": "Profile not found" })),
        )
            .into_response(),
        Err(err) => {
            tracing::error!("users get_profile failed: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
    }
}
