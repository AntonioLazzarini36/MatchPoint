//! Direct port of me.controller.ts.

use axum::{
    extract::{Multipart, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, patch, post},
    Json, Router,
};
use serde_json::json;
use utoipa::ToSchema;

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::discover::service::SkillLevelEntry;
use crate::me::dto::{
    DeletePhotoDto, UpdatePreferencesDto, UpdateProfileDto, UpdateSkillLevelsDto,
};
use crate::me::photos::PhotoError;
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
        .route("/me/skill-levels", patch(update_skill_levels))
        .route("/me/photos", post(add_photo).delete(remove_photo))
}

/// Doc-only shape of the multipart body `POST /me/photos` expects — never
/// constructed, exists purely so utoipa can describe the binary field.
#[derive(ToSchema)]
#[allow(dead_code)]
pub(crate) struct PhotoUploadForm {
    #[schema(value_type = String, format = Binary)]
    photo: Vec<u8>,
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

#[utoipa::path(
    patch,
    path = "/me/skill-levels",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body = UpdateSkillLevelsDto,
    responses(
        (status = 200, description = "Nivel actualizado por deporte (upsert por sport, no toca los deportes no incluidos)", body = Vec<SkillLevelEntry>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn update_skill_levels(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<UpdateSkillLevelsDto>,
) -> impl IntoResponse {
    match service::update_skill_levels(&state, &user.user_id, dto).await {
        Ok(levels) => Json(levels).into_response(),
        Err(e) => me_error_response(e),
    }
}

#[utoipa::path(
    post,
    path = "/me/photos",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body(content = PhotoUploadForm, content_type = "multipart/form-data"),
    responses(
        (status = 200, description = "Foto subida y añadida al perfil", body = Profile),
        (status = 400, description = "Archivo inválido, demasiado grande, o límite de fotos alcanzado", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 404, description = "Completa tu perfil antes de subir fotos", body = ErrorResponse),
    )
)]
async fn add_photo(
    State(state): State<AppState>,
    user: AuthUser,
    multipart: Multipart,
) -> impl IntoResponse {
    match service::add_photo(&state, &user.user_id, multipart).await {
        Ok(profile) => Json(profile).into_response(),
        Err(e) => me_error_response(e),
    }
}

#[utoipa::path(
    delete,
    path = "/me/photos",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body = DeletePhotoDto,
    responses(
        (status = 200, description = "Foto eliminada del perfil", body = Profile),
        (status = 400, description = "No puedes borrar tu última foto", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 404, description = "Perfil no encontrado", body = ErrorResponse),
    )
)]
async fn remove_photo(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<DeletePhotoDto>,
) -> impl IntoResponse {
    match service::remove_photo(&state, &user.user_id, &dto.url).await {
        Ok(profile) => Json(profile).into_response(),
        Err(e) => me_error_response(e),
    }
}

fn me_error_response(err: MeError) -> axum::response::Response {
    let status = match &err {
        MeError::UserNotFound | MeError::ProfileNotFound => StatusCode::NOT_FOUND,
        MeError::TooManyPhotos | MeError::LastPhotoRequired | MeError::InvalidInput(_) => {
            StatusCode::BAD_REQUEST
        }
        MeError::Photo(
            PhotoError::UnsupportedContentType(_)
            | PhotoError::TooLarge
            | PhotoError::MissingField
            | PhotoError::Multipart(_),
        ) => StatusCode::BAD_REQUEST,
        MeError::Photo(PhotoError::Io(_)) => StatusCode::INTERNAL_SERVER_ERROR,
        MeError::Db(_) | MeError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
    };
    (status, Json(json!({ "message": err.to_string() }))).into_response()
}
