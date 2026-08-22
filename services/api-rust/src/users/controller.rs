//! Direct port of users.controller.ts, plus report — not in the original
//! NestJS app, added directly here since there's no separate TS version
//! to mirror.

use axum::{
    extract::{Path, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::auth::rate_limit;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::discover::service::DiscoverProfile;
#[allow(unused_imports)]
use crate::openapi::{ErrorResponse, OkResponse};
use crate::state::AppState;
use crate::users::dto::ReportUserDto;
use crate::users::service::{self, UsersError};

pub fn router(state: AppState) -> Router<AppState> {
    // Solo el reporte lleva limite: ver un perfil es navegacion normal y
    // limitarlo romperia el uso legitimo de la app.
    let limited = Router::new()
        .route("/users/:userId/report", post(report_user))
        .route_layer(middleware::from_fn_with_state(
            state,
            rate_limit::limit_reports,
        ));

    Router::new()
        .route("/users/:userId/profile", get(get_profile))
        .merge(limited)
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
        Err(err @ UsersError::ProfileNotFound) => {
            crate::http_error::respond(StatusCode::NOT_FOUND, err)
        }
        Err(err) => crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err),
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
        UsersError::CannotTargetSelf | UsersError::InvalidReason => {
            crate::http_error::respond(StatusCode::BAD_REQUEST, err)
        }
        UsersError::UserNotFound => crate::http_error::respond(StatusCode::NOT_FOUND, err),
        UsersError::ProfileNotFound => crate::http_error::respond(StatusCode::NOT_FOUND, err),
        err => {
            tracing::error!("users error: {err}");
            crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err)
        }
    }
}
