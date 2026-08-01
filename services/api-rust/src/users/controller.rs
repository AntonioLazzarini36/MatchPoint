//! Direct port of users.controller.ts, plus report — not in the original
//! NestJS app, added directly here since there's no separate TS version
//! to mirror.

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde_json::json;

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::discover::service::DiscoverProfile;
#[allow(unused_imports)]
use crate::openapi::{ErrorResponse, OkResponse};
use crate::state::AppState;
use crate::users::dto::ReportUserDto;
use crate::users::service::{self, UsersError};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/:userId/profile", get(get_profile))
        .route("/users/:userId/report", post(report_user))
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

#[utoipa::path(
    post,
    path = "/users/{userId}/report",
    tag = "users",
    security(("bearerAuth" = [])),
    params(("userId" = String, Path, description = "Id del usuario a reportar")),
    request_body = ReportUserDto,
    responses(
        (status = 200, description = "Reporte registrado (no borra el match; eso es un unmatch aparte)", body = OkResponse),
        (status = 400, description = "No puedes reportarte a ti mismo", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn report_user(
    State(state): State<AppState>,
    user: AuthUser,
    Path(user_id): Path<String>,
    Json(dto): Json<ReportUserDto>,
) -> impl IntoResponse {
    match service::report_user(&state, &user.user_id, &user_id, &dto.reason).await {
        Ok(()) => Json(json!({ "ok": true })).into_response(),
        Err(err) => users_error_response(err),
    }
}

fn users_error_response(err: UsersError) -> axum::response::Response {
    match err {
        UsersError::CannotTargetSelf => (
            StatusCode::BAD_REQUEST,
            Json(json!({ "message": err.to_string() })),
        )
            .into_response(),
        UsersError::ProfileNotFound => (
            StatusCode::NOT_FOUND,
            Json(json!({ "message": err.to_string() })),
        )
            .into_response(),
        err => {
            tracing::error!("users error: {err}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
    }
}
