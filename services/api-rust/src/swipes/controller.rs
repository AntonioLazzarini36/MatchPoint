//! Direct port of swipes.controller.ts.

use axum::{
    extract::State, http::StatusCode, response::IntoResponse, routing::post, Json, Router,
};
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::state::AppState;
use crate::swipes::dto::CreateSwipeDto;
use crate::swipes::service::{self, SwipesError};

pub fn router() -> Router<AppState> {
    Router::new().route("/swipes", post(create_swipe))
}

async fn create_swipe(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<CreateSwipeDto>,
) -> impl IntoResponse {
    match service::create_swipe(&state, &user.user_id, dto).await {
        Ok(result) => Json(result).into_response(),
        Err(err) => {
            let status = match &err {
                SwipesError::CannotSwipeSelf => StatusCode::BAD_REQUEST,
                SwipesError::Db(_) | SwipesError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
            };
            (status, Json(json!({ "message": err.to_string() }))).into_response()
        }
    }
}