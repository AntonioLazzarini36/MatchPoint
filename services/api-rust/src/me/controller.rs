//! Direct port of me.controller.ts.

use axum::{
    extract::{Multipart, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{delete, get, patch, post},
    Json, Router,
};
use utoipa::ToSchema;

use crate::auth::jwt::AuthUser;
use crate::auth::rate_limit;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::discover::service::SkillLevelEntry;
use crate::me::dto::{
    DeletePhotoDto, RegisterDeviceDto, UnregisterDeviceDto, UpdatePreferencesDto, UpdateProfileDto,
    UpdateSkillLevelsDto,
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

pub fn router(state: AppState) -> Router<AppState> {
    // Subir foto es el endpoint mas caro (escribe en disco) y el unico por el
    // que una cuenta puede llenar el volumen, que ademas se paga. Borrar no
    // lleva limite: no cuesta nada y bloquearlo dejaria fotos que no se
    // pueden quitar.
    let limited = Router::new()
        .route("/me/photos", post(add_photo))
        .route_layer(middleware::from_fn_with_state(
            state,
            rate_limit::limit_photos,
        ));

    Router::new()
        .route("/me", get(get_me).delete(delete_account))
        .route("/me/profile", patch(update_profile))
        .route("/me/preferences", patch(update_preferences))
        .route("/me/skill-levels", patch(update_skill_levels))
        .route("/me/photos", delete(remove_photo))
        .route(
            "/me/devices",
            post(register_device).delete(unregister_device),
        )
        .merge(limited)
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
            PhotoError::NotAnImage
            | PhotoError::TooLarge
            | PhotoError::MissingField
            | PhotoError::Multipart(_),
        ) => StatusCode::BAD_REQUEST,
        MeError::Photo(PhotoError::Io(_)) => StatusCode::INTERNAL_SERVER_ERROR,
        MeError::Db(_) | MeError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
    };
    crate::http_error::respond(status, err)
}

/// Borra la cuenta del usuario autenticado, sin vuelta atrás.
///
/// No pide confirmación aquí: eso es cosa de la interfaz, que además la
/// pide escribiendo la palabra "BORRAR". Un endpoint que exigiera un
/// segundo parámetro de confirmación sería seguridad de mentira — quien
/// llame a la API directamente lo mandaría igual.
#[utoipa::path(
    delete,
    path = "/me",
    tag = "me",
    security(("bearerAuth" = [])),
    responses(
        (status = 204, description = "Cuenta borrada"),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 404, description = "Usuario no encontrado", body = ErrorResponse),
    )
)]
async fn delete_account(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::delete_account(&state, &user.user_id).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(err) => me_error_response(err),
    }
}

/// Alta del dispositivo para recibir notificaciones push.
///
/// Idempotente a propósito: el móvil lo llama en cada arranque y cada vez
/// que FCM rota el token, sin comprobar antes si ya estaba.
#[utoipa::path(
    post,
    path = "/me/devices",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body = RegisterDeviceDto,
    responses(
        (status = 204, description = "Dispositivo registrado"),
        (status = 400, description = "Token o plataforma inválidos", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn register_device(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<RegisterDeviceDto>,
) -> impl IntoResponse {
    match service::register_device(&state, &user.user_id, dto).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(err) => me_error_response(err),
    }
}

/// Baja del dispositivo, al cerrar sesión.
#[utoipa::path(
    delete,
    path = "/me/devices",
    tag = "me",
    security(("bearerAuth" = [])),
    request_body = UnregisterDeviceDto,
    responses(
        (status = 204, description = "Dispositivo dado de baja"),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn unregister_device(
    State(state): State<AppState>,
    user: AuthUser,
    Json(dto): Json<UnregisterDeviceDto>,
) -> impl IntoResponse {
    match service::unregister_device(&state, &user.user_id, &dto.token).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(err) => me_error_response(err),
    }
}
