//! Direct port of discover.controller.ts.

use axum::{
    extract::{Query, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::auth::jwt::AuthUser;
use crate::auth::rate_limit;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::discover::service::DiscoverProfile;
use crate::discover::service::{self, DiscoverError, DiscoverFilters};
use crate::models::{SkillLevel, Sport};
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router(state: AppState) -> Router<AppState> {
    // `/discover/density` no lleva token a propósito (ver `service::density`):
    // se llama desde el paso de ubicación del registro, donde todavía no hay
    // cuenta. A cambio va limitada por IP, con su propia cuota (`DENSITY`):
    // la de auth es de 10/min y aquí mover el radio o cambiar de ciudad son
    // gestos normales que se repiten.
    let public = Router::new()
        .route("/discover/density", get(density))
        .route_layer(middleware::from_fn_with_state(
            state,
            rate_limit::density_rate_limit,
        ));

    Router::new()
        .route("/discover", get(discover))
        .merge(public)
}

/// Qué se le pide al feed.
///
/// `Option<Sport>` significa que un `?sport=` ausente o vacío deserializa a
/// `None` — sin filtro de deporte, igual que la versión TS.
#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct DiscoverQuery {
    sport: Option<Sport>,
    /// Máscara de 21 bits (`bit = día * 3 + franja`, ver
    /// `models::Profile::availability`): sólo sale quien tenga algún hueco
    /// dentro de ella. Es el filtro de "cuándo puedo jugar", el que convirtió
    /// esta pantalla en una búsqueda en vez de un mazo de caras.
    availability: Option<i32>,
    /// Sólo gente con este nivel declarado en el deporte pedido.
    level: Option<SkillLevel>,
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
    let filters = DiscoverFilters {
        sport: params.sport,
        availability: params.availability,
        level: params.level,
    };
    match service::discover(&state, &user.user_id, filters).await {
        Ok(profiles) => Json(profiles).into_response(),
        Err(err @ DiscoverError::SportNotYours) => {
            crate::http_error::respond(StatusCode::BAD_REQUEST, err)
        }
        // `respond` ya registra el detalle en el log y no lo saca al cliente.
        Err(err) => crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err),
    }
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct DensityQuery {
    lat: f64,
    lng: f64,
    /// Radio en km. Se recorta a 1-300 en el servicio.
    #[serde(rename = "radiusKm")]
    radius_km: f64,
    /// Por defecto tenis, que es el único deporte que la app ofrece hoy.
    sport: Option<Sport>,
}

/// Sólo un número: cuánta gente hay, no quién.
#[derive(Debug, Serialize, ToSchema)]
pub struct DensityResponse {
    pub count: i64,
}

#[utoipa::path(
    get,
    path = "/discover/density",
    tag = "discover",
    params(DensityQuery),
    responses(
        (status = 200, description = "Cuántos perfiles completos hay en ese radio", body = DensityResponse),
        (status = 400, description = "Coordenadas fuera de rango", body = ErrorResponse),
        (status = 429, description = "Demasiadas peticiones desde esta IP", body = ErrorResponse),
    )
)]
async fn density(
    State(state): State<AppState>,
    Query(params): Query<DensityQuery>,
) -> impl IntoResponse {
    if !(-90.0..=90.0).contains(&params.lat) || !(-180.0..=180.0).contains(&params.lng) {
        return crate::http_error::respond(
            StatusCode::BAD_REQUEST,
            "Coordenadas fuera de rango".to_string(),
        );
    }

    let sport = params.sport.unwrap_or(Sport::Tennis);
    match service::density(&state, params.lat, params.lng, params.radius_km, sport).await {
        Ok(count) => Json(DensityResponse { count }).into_response(),
        Err(err) => crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err),
    }
}
