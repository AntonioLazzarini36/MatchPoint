//! Direct port of me.controller.ts.

use axum::{
    extract::State, http::StatusCode, response::IntoResponse, routing::get, routing::patch, Json,
    Router,
};
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::me::dto::{UpdatePreferencesDto, UpdateProfileDto};
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::me::service::MeResponse;
use crate::me::service::{self, MeError};
#[allow(unused_imports)]
use crate::models::{Preferences, Profile};
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/me", get(get_me))
        .route("/me/profile", patch(update_profile))
        .route("/me/preferences", patch(update_preferences))
}

#[utoipa::path(
    get,
    path = "/me",
    tag = "me",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Perfil + preferencias del usuario autenticado", body = MeResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 404, description = "Usuario no encontrado", body = ErrorResponse),
    )
)]
async fn get_me(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::get_me(&state, &user.user_id).await {
        Ok(me) => Json(me).into_response(),
        Err(e) => me_error_response(e),
    }
}

#[utoipa::path(
    patch,
    path = "/me/profile",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body = UpdateProfileDto,
    responses(
        (status = 200, description = "Perfil actualizado (upsert parcial)", body = Profile),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn update_profile(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<UpdateProfileDto>,
) -> impl IntoResponse {
    match service::update_profile(&state, &user.user_id, dto).await {
        Ok(profile) => Json(profile).into_response(),
        Err(e) => me_error_response(e),
    }
}

#[utoipa::path(
    patch,
    path = "/me/preferences",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body = UpdatePreferencesDto,
    responses(
        (status = 200, description = "Preferencias actualizadas (upsert parcial)", body = Preferences),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn update_preferences(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<UpdatePreferencesDto>,
) -> impl IntoResponse {
    match service::update_preferences(&state, &user.user_id, dto).await {
        Ok(prefs) => Json(prefs).into_response(),
        Err(e) => me_error_response(e),
    }
}

fn me_error_response(err: MeError) -> axum::response::Response {
    let status = match &err {
        MeError::UserNotFound => StatusCode::NOT_FOUND,
        MeError::Db(_) | MeError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
    };
    (status, Json(json!({ "message": err.to_string() }))).into_response()
}
