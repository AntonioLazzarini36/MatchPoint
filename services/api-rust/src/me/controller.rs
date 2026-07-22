//! Direct port of me.controller.ts.

use axum::{
    extract::State, http::StatusCode, response::IntoResponse, routing::get, routing::patch, Json,
    Router,
};
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::me::dto::{UpdatePreferencesDto, UpdateProfileDto};
use crate::me::service::{self, MeError};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/me", get(get_me))
        .route("/me/profile", patch(update_profile))
        .route("/me/preferences", patch(update_preferences))
}

async fn get_me(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::get_me(&state, &user.user_id).await {
        Ok(me) => Json(me).into_response(),
        Err(e) => me_error_response(e),
    }
}

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
