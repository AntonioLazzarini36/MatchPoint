//! OpenAPI spec aggregation. `ApiDoc` lists every handler (`paths(...)`)
//! and every request/response type (`components(schemas(...))`) that
//! make up the API. Served as JSON + Swagger UI from `app.rs`.
//!
//! To document a new endpoint: add `ToSchema` to its DTO/response
//! type(s), add a `#[utoipa::path(...)]` block above the handler (copy
//! a neighboring one in the same module), then list the handler and any
//! new schema types below.

use serde::Serialize;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::{Modify, OpenApi, ToSchema};

/// Shape used for every error response across the API: `{ "message": "..." }`.
/// Not wired into a shared runtime type — every controller builds this
/// literally with `json!({ "message": ... })` — this struct exists only
/// so the OpenAPI spec can describe that shape.
#[derive(Debug, Serialize, ToSchema)]
pub struct ErrorResponse {
    pub message: String,
}

/// Shape of the plain `{ "ok": true }` responses (`/health`, `/auth/logout`).
#[derive(Debug, Serialize, ToSchema)]
pub struct OkResponse {
    pub ok: bool,
}

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::app::controller::get_hello,
        crate::app::controller::health,
        crate::auth::controller::email_available,
        crate::auth::controller::register,
        crate::auth::controller::login,
        crate::auth::controller::refresh,
        crate::auth::controller::logout,
        crate::me::controller::get_me,
        crate::me::controller::update_profile,
        crate::me::controller::update_preferences,
        crate::me::controller::add_photo,
        crate::me::controller::remove_photo,
        crate::discover::controller::discover,
        crate::swipes::controller::create_swipe,
        crate::matches::controller::list,
        crate::matches::controller::unmatch,
        crate::chats::controller::list_messages,
        crate::chats::controller::send_message,
        crate::chats::controller::mark_read,
        crate::users::controller::get_profile,
        crate::users::controller::report_user,
    ),
    components(schemas(
        ErrorResponse,
        OkResponse,
        crate::models::Sport,
        crate::models::SwipeType,
        crate::models::Profile,
        crate::models::Preferences,
        crate::auth::dto::RegisterDto,
        crate::auth::dto::LoginDto,
        crate::auth::dto::RefreshDto,
        crate::auth::dto::LogoutDto,
        crate::auth::service::AuthTokens,
        crate::auth::service::EmailAvailability,
        crate::me::dto::UpdateProfileDto,
        crate::me::dto::UpdatePreferencesDto,
        crate::me::dto::DeletePhotoDto,
        crate::me::controller::PhotoUploadForm,
        crate::me::service::MeResponse,
        crate::discover::service::DiscoverProfile,
        crate::swipes::dto::CreateSwipeDto,
        crate::swipes::service::SwipeResult,
        crate::matches::service::UserWithProfile,
        crate::matches::service::OtherUserWithProfile,
        crate::matches::service::LastMessagePreview,
        crate::matches::service::MatchListItem,
        crate::chats::dto::SendMessageDto,
        crate::chats::service::MessageResponse,
        crate::chats::service::MarkReadResponse,
        crate::users::dto::ReportUserDto,
    )),
    tags(
        (name = "misc", description = "Endpoints de estado"),
        (name = "auth", description = "Registro, login y ciclo de vida de tokens JWT"),
        (name = "me", description = "Perfil y preferencias del usuario autenticado"),
        (name = "discover", description = "Descubrimiento de perfiles para swipear"),
        (name = "swipes", description = "Likes/pases y creación de matches"),
        (name = "matches", description = "Matches del usuario autenticado"),
        (name = "chats", description = "Mensajes dentro de un match"),
        (name = "users", description = "Perfiles públicos de otros usuarios"),
    ),
    modifiers(&SecurityAddon)
)]
pub struct ApiDoc;

struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi
            .components
            .as_mut()
            .expect("components already registered by #[openapi(components(...))]");
        components.add_security_scheme(
            "bearerAuth",
            SecurityScheme::Http(
                HttpBuilder::new()
                    .scheme(HttpAuthScheme::Bearer)
                    .bearer_format("JWT")
                    .build(),
            ),
        );
    }
}
