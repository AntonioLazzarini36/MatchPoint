use axum::{
    extract::{Query, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::json;

use crate::auth::dto::{LoginDto, LogoutDto, RefreshDto, RegisterDto};
use crate::auth::rate_limit;
use crate::auth::service::{self, AuthError};
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::auth::service::{AuthTokens, EmailAvailability};
#[allow(unused_imports)]
use crate::openapi::{ErrorResponse, OkResponse};
use crate::state::AppState;

pub fn router(state: AppState) -> Router<AppState> {
    // Only the brute-force/enumeration-prone endpoints are rate-limited;
    // refresh/logout are called routinely by legitimate clients.
    let rate_limited = Router::new()
        .route("/auth/email-available", get(email_available))
        .route("/auth/register", post(register))
        .route("/auth/login", post(login))
        .route_layer(middleware::from_fn_with_state(
            state,
            rate_limit::rate_limit,
        ));

    Router::new()
        .merge(rate_limited)
        .route("/auth/refresh", post(refresh))
        .route("/auth/logout", post(logout))
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct EmailAvailableQuery {
    email: String,
}

#[utoipa::path(
    get,
    path = "/auth/email-available",
    tag = "auth",
    params(EmailAvailableQuery),
    responses(
        (status = 200, description = "Si el email ya está registrado o no", body = EmailAvailability),
        (status = 429, description = "Demasiadas peticiones desde esta IP, reintentar más tarde", body = ErrorResponse),
    )
)]
async fn email_available(
    State(state): State<AppState>,
    Query(params): Query<EmailAvailableQuery>,
) -> impl IntoResponse {
    match service::email_available(&state, &params.email).await {
        Ok(available) => Json(EmailAvailability { available }).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/register",
    tag = "auth",
    request_body = RegisterDto,
    responses(
        (status = 200, description = "Cuenta creada, tokens emitidos", body = AuthTokens),
        (status = 400, description = "El email ya está en uso", body = ErrorResponse),
        (status = 429, description = "Demasiadas peticiones desde esta IP, reintentar más tarde", body = ErrorResponse),
    )
)]
async fn register(
    State(state): State<AppState>,
    Json(dto): Json<RegisterDto>,
) -> impl IntoResponse {
    match service::register(&state, dto).await {
        Ok(t) => Json(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/login",
    tag = "auth",
    request_body = LoginDto,
    responses(
        (status = 200, description = "Login correcto, tokens emitidos", body = AuthTokens),
        (status = 401, description = "Credenciales inválidas", body = ErrorResponse),
        (status = 429, description = "Demasiadas peticiones desde esta IP, reintentar más tarde", body = ErrorResponse),
    )
)]
async fn login(State(state): State<AppState>, Json(dto): Json<LoginDto>) -> impl IntoResponse {
    match service::login(&state, dto).await {
        Ok(t) => Json(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/refresh",
    tag = "auth",
    request_body = RefreshDto,
    responses(
        (status = 200, description = "Nuevo par de tokens", body = AuthTokens),
        (status = 401, description = "Refresh token inválido, caducado o revocado", body = ErrorResponse),
    )
)]
async fn refresh(State(state): State<AppState>, Json(dto): Json<RefreshDto>) -> impl IntoResponse {
    match service::refresh(&state, &dto.refresh_token).await {
        Ok(t) => Json(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/logout",
    tag = "auth",
    request_body = LogoutDto,
    responses(
        (status = 200, description = "Refresh token revocado (siempre 200, incluso si ya era inválido)", body = OkResponse),
    )
)]
async fn logout(State(state): State<AppState>, Json(dto): Json<LogoutDto>) -> impl IntoResponse {
    match service::logout(&state, &dto.refresh_token).await {
        Ok(()) => Json(json!({ "ok": true })).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

struct AuthRejection(AuthError);

impl IntoResponse for AuthRejection {
    fn into_response(self) -> axum::response::Response {
        let status = match &self.0 {
            AuthError::EmailInUse | AuthError::InvalidEmail | AuthError::InvalidPassword => {
                StatusCode::BAD_REQUEST
            }
            AuthError::InvalidCredentials
            | AuthError::MissingRefreshToken
            | AuthError::InvalidRefreshToken
            | AuthError::RefreshTokenRevoked
            | AuthError::RefreshTokenMismatch
            | AuthError::UserNotFound => StatusCode::UNAUTHORIZED,
            AuthError::Db(_) | AuthError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
        };
        (status, Json(json!({ "message": self.0.to_string() }))).into_response()
    }
}
