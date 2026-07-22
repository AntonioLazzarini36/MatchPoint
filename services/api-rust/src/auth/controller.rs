use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::post,
    Json, Router};
use serde_json::json;

use crate::auth::dto::{LoginDto, LogoutDto, RefreshDto, RegisterDto};
use crate::auth::service::{self, AuthError};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/auth/register", post(register))
        .route("/auth/login", post(login))
        .route("/auth/refresh", post(refresh))
        .route("/auth/logout", post(logout))
}

async fn register(State(state): State<AppState>, Json(dto): Json<RegisterDto>) -> impl IntoResponse {
    match service::register(&state, dto).await {
        Ok(t) => tokens_response(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

async fn login(State(state): State<AppState>, Json(dto): Json<LoginDto>) -> impl IntoResponse {
    match service::login(&state, dto).await {
        Ok(t) => tokens_response(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

async fn refresh(State(state): State<AppState>, Json(dto): Json<RefreshDto>) -> impl IntoResponse {
    match service::refresh(&state, &dto.refresh_token).await {
        Ok(t) => tokens_response(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

async fn logout(State(state): State<AppState>, Json(dto): Json<LogoutDto>) -> impl IntoResponse {
    match service::logout(&state, &dto.refresh_token).await {
        Ok(()) => Json(json!({ "ok": true })).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

fn tokens_response(t: service::AuthTokens) -> Json<serde_json::Value> {
    Json(json!({
        "userId": t.user_id,
        "accessToken": t.access_token,
        "refreshToken": t.refresh_token,
    }))
}

struct AuthRejection(AuthError);

impl IntoResponse for AuthRejection {
    fn into_response(self) -> axum::response::Response {
        let status = match &self.0 {
            AuthError::EmailInUse => StatusCode::BAD_REQUEST,
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