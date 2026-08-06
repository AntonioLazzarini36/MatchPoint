//! Direct port of discover.controller.ts.

use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::json;

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::discover::service::DiscoverProfile;
use crate::discover::service::{self, DiscoverError};
use crate::models::Sport;
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/discover", get(discover))
}

/// Equivalent of `@Query('sport') sport?: Sport` in discover.controller.ts.
/// `Option<Sport>` means a missing or empty `?sport=` just deserializes to
/// `None` — no sport filter applied, same as the TS version.
#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct DiscoverQuery {
    sport: Option<Sport>,
}

// Equivalent of `@UseGuards(JwtAuthGuard)` + `@Req() req: AuthenticatedRequest`:
// the `AuthUser` extractor runs before this function's body even starts,
// and rejects the request with 401 on its own if the token is missing/bad.
#[utoipa::path(
    get,
    path = "/discover",
    tag = "discover",
    security(("bearerAuth" = [])),
    params(DiscoverQuery),
    responses(
        (status = 200, description = "Perfiles candidatos para el deporte pedido (o todos si se omite)", body = Vec<DiscoverProfile>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn discover(
    State(state): State<AppState>,
    user: AuthUser,
    Query(params): Query<DiscoverQuery>,
) -> impl IntoResponse {
    match service::discover(&state, &user.user_id, params.sport).await {
        Ok(profiles) => Json(profiles).into_response(),
        Err(err @ DiscoverError::SportNotYours) => (
            StatusCode::BAD_REQUEST,
            Json(json!({ "message": err.to_string() })),
        )
            .into_response(),
        Err(DiscoverError::Db(e)) => {
            tracing::error!("discover query failed: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
        Err(DiscoverError::Pool(e)) => {
            tracing::error!("discover pool error: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "message": "Internal server error" })),
            )
                .into_response()
        }
    }
}
