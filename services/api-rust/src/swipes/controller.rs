//! Direct port of swipes.controller.ts.

use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::post, Json, Router};
use serde_json::json;

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::openapi::ErrorResponse;
use crate::state::AppState;
use crate::swipes::dto::CreateSwipeDto;
#[allow(unused_imports)]
use crate::swipes::service::SwipeResult;
use crate::swipes::service::{self, SwipesError};

pub fn router() -> Router<AppState> {
    Router::new().route("/swipes", post(create_swipe))
}

#[utoipa::path(
    post,
    path = "/swipes",
    tag = "swipes",
    security(("bearerAuth" = [])),
    request_body = CreateSwipeDto,
    responses(
        (status = 200, description = "Swipe registrado; incluye si generó match", body = SwipeResult),
        (status = 400, description = "No se puede swipear a uno mismo", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
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
