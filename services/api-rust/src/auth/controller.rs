use axum::{
    extract::{Query, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::json;

use crate::auth::dto::{LoginDto, LogoutDto, RefreshDto, RegisterDto};
use crate::auth::rate_limit;
use crate::auth::service::{self, AuthError};
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::auth::service::{AuthTokens, EmailAvailability};
#[allow(unused_imports)]
use crate::openapi::{ErrorResponse, OkResponse};
use crate::state::AppState;

pub fn router(state: AppState) -> Router<AppState> {
    // Only the brute-force/enumeration-prone endpoints are rate-limited;
    // refresh/logout are called routinely by legitimate clients.
    let rate_limited = Router::new()
        .route("/auth/email-available", get(email_available))
        .route("/auth/register", post(register))
        .route("/auth/login", post(login))
        // Los dos de recuperación van aquí y no en el grupo libre: no piden
        // token (quien los usa es justamente quien no puede entrar), así que
        // sin límite serían un buzón abierto para probar códigos y para
        // bombardear el correo de otra persona.
        .route("/auth/forgot-password", post(forgot_password))
        .route("/auth/reset-password", post(reset_password))
        .route_layer(middleware::from_fn_with_state(
            state,
            rate_limit::rate_limit,
        ));

    Router::new()
        .merge(rate_limited)
        .route("/auth/refresh", post(refresh))
        .route("/auth/logout", post(logout))
        .route("/auth/send-verification", post(send_verification))
        .route("/auth/verify-email", post(verify_email))
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct EmailAvailableQuery {
    email: String,
}

#[utoipa::path(
    get,
    path = "/auth/email-available",
    tag = "auth",
    params(EmailAvailableQuery),
    responses(
        (status = 200, description = "Si el email ya está registrado o no", body = EmailAvailability),
        (status = 429, description = "Demasiadas peticiones desde esta IP, reintentar más tarde", body = ErrorResponse),
    )
)]
async fn email_available(
    State(state): State<AppState>,
    Query(params): Query<EmailAvailableQuery>,
) -> impl IntoResponse {
    match service::email_available(&state, &params.email).await {
        Ok(available) => Json(EmailAvailability { available }).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/register",
    tag = "auth",
    request_body = RegisterDto,
    responses(
        (status = 200, description = "Cuenta creada, tokens emitidos", body = AuthTokens),
        (status = 400, description = "El email ya está en uso", body = ErrorResponse),
        (status = 429, description = "Demasiadas peticiones desde esta IP, reintentar más tarde", body = ErrorResponse),
    )
)]
async fn register(
    State(state): State<AppState>,
    Json(dto): Json<RegisterDto>,
) -> impl IntoResponse {
    match service::register(&state, dto).await {
        Ok(t) => Json(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/login",
    tag = "auth",
    request_body = LoginDto,
    responses(
        (status = 200, description = "Login correcto, tokens emitidos", body = AuthTokens),
        (status = 401, description = "Credenciales inválidas", body = ErrorResponse),
        (status = 429, description = "Demasiadas peticiones desde esta IP, reintentar más tarde", body = ErrorResponse),
    )
)]
async fn login(State(state): State<AppState>, Json(dto): Json<LoginDto>) -> impl IntoResponse {
    match service::login(&state, dto).await {
        Ok(t) => Json(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/refresh",
    tag = "auth",
    request_body = RefreshDto,
    responses(
        (status = 200, description = "Nuevo par de tokens", body = AuthTokens),
        (status = 401, description = "Refresh token inválido, caducado o revocado", body = ErrorResponse),
    )
)]
async fn refresh(State(state): State<AppState>, Json(dto): Json<RefreshDto>) -> impl IntoResponse {
    match service::refresh(&state, &dto.refresh_token).await {
        Ok(t) => Json(t).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/logout",
    tag = "auth",
    request_body = LogoutDto,
    responses(
        (status = 200, description = "Refresh token revocado (siempre 200, incluso si ya era inválido)", body = OkResponse),
    )
)]
async fn logout(State(state): State<AppState>, Json(dto): Json<LogoutDto>) -> impl IntoResponse {
    match service::logout(&state, &dto.refresh_token).await {
        Ok(()) => Json(json!({ "ok": true })).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

struct AuthRejection(AuthError);

impl IntoResponse for AuthRejection {
    fn into_response(self) -> axum::response::Response {
        let status = match &self.0 {
            AuthError::EmailInUse | AuthError::InvalidEmail | AuthError::InvalidPassword => {
                StatusCode::BAD_REQUEST
            }
            AuthError::InvalidCredentials
            | AuthError::MissingRefreshToken
            | AuthError::InvalidRefreshToken
            | AuthError::RefreshTokenRevoked
            | AuthError::RefreshTokenMismatch
            | AuthError::UserNotFound => StatusCode::UNAUTHORIZED,
            AuthError::EmailAlreadyVerified | AuthError::InvalidCode | AuthError::CodeExpired => {
                StatusCode::BAD_REQUEST
            }
            // 429 y no 400: son límites de ritmo, y el cliente puede
            // reintentar más tarde sin cambiar nada de lo que manda.
            AuthError::CodeRequestedTooSoon(_) | AuthError::TooManyCodeAttempts => {
                StatusCode::TOO_MANY_REQUESTS
            }
            // El correo lo manda un tercero: si falla, el fallo es nuestro
            // (o suyo), no de quien lo pidió.
            AuthError::MailFailed(_) => StatusCode::BAD_GATEWAY,
            // 503 y no 400: la peticion es correcta, es el servicio el que
            // no esta disponible — y volvera a estarlo al encender el flag.
            AuthError::EmailVerificationDisabled | AuthError::MailDisabled => {
                StatusCode::SERVICE_UNAVAILABLE
            }
            AuthError::Db(_) | AuthError::Pool(_) => StatusCode::INTERNAL_SERVER_ERROR,
        };
        // `MailFailed` lleva dentro el error del proveedor de correo. Es un
        // 5xx, asi que `respond` ya se encarga de que no salga.
        crate::http_error::respond(status, self.0)
    }
}

#[derive(Debug, serde::Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct VerifyEmailDto {
    /// Código de 6 dígitos recibido por correo.
    pub code: String,
}

/// Pide (o reenvía) el código de verificación al email de la cuenta.
///
/// Requiere estar autenticado a propósito: así el código sólo puede
/// pedirse para la propia cuenta y nadie puede usar este endpoint para
/// bombardear el buzón de otra persona metiendo su email.
#[utoipa::path(
    post,
    path = "/auth/send-verification",
    tag = "auth",
    security(("bearerAuth" = [])),
    responses(
        (status = 204, description = "Código enviado"),
        (status = 400, description = "El email ya estaba verificado", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 429, description = "Pedido demasiado pronto tras el anterior", body = ErrorResponse),
        (status = 502, description = "El proveedor de email falló", body = ErrorResponse),
    )
)]
async fn send_verification(
    State(state): State<AppState>,
    user: crate::auth::jwt::AuthUser,
) -> impl IntoResponse {
    match service::send_verification_code(&state, &user.user_id).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/auth/verify-email",
    tag = "auth",
    security(("bearerAuth" = [])),
    request_body = VerifyEmailDto,
    responses(
        (status = 200, description = "Email verificado", body = OkResponse),
        (status = 400, description = "Código incorrecto o caducado", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 429, description = "Demasiados intentos con el mismo código", body = ErrorResponse),
    )
)]
async fn verify_email(
    State(state): State<AppState>,
    user: crate::auth::jwt::AuthUser,
    Json(dto): Json<VerifyEmailDto>,
) -> impl IntoResponse {
    match service::verify_email(&state, &user.user_id, dto.code.trim()).await {
        Ok(()) => Json(json!({ "ok": true })).into_response(),
        Err(e) => AuthRejection(e).into_response(),
    }
}

#[derive(Debug, Deserialize, utoipa::ToSchema)]
pub struct ForgotPasswordDto {
    pub email: String,
}

#[derive(Debug, Deserialize, utoipa::ToSchema)]
pub struct ResetPasswordDto {
    pub email: String,
    pub code: String,
    #[serde(rename = "newPassword")]
    pub new_password: String,
}

/// Pide un código para recuperar la contraseña.
///
/// **Contesta 204 exista la cuenta o no**, a propósito: si distinguiera, este
/// endpoint —que no lleva token, porque quien lo usa no puede entrar— serviría
/// para averiguar quién tiene cuenta aquí probando correos ajenos.
#[utoipa::path(
    post,
    path = "/auth/forgot-password",
    tag = "auth",
    request_body = ForgotPasswordDto,
    responses(
        (status = 204, description = "Si esa cuenta existe, se le ha enviado un código"),
        (status = 429, description = "Demasiadas peticiones, o código pedido hace muy poco", body = ErrorResponse),
    )
)]
async fn forgot_password(
    State(state): State<AppState>,
    Json(dto): Json<ForgotPasswordDto>,
) -> impl IntoResponse {
    match service::request_password_reset(&state, &dto.email).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(err @ AuthError::MailDisabled) => {
            crate::http_error::respond(StatusCode::SERVICE_UNAVAILABLE, err)
        }
        Err(err @ AuthError::CodeRequestedTooSoon(_)) => {
            crate::http_error::respond(StatusCode::TOO_MANY_REQUESTS, err)
        }
        Err(err @ AuthError::MailFailed(_)) => {
            crate::http_error::respond(StatusCode::BAD_GATEWAY, err)
        }
        Err(err) => crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err),
    }
}

/// Cambia la contraseña con el código recibido. Cierra todas las sesiones.
#[utoipa::path(
    post,
    path = "/auth/reset-password",
    tag = "auth",
    request_body = ResetPasswordDto,
    responses(
        (status = 204, description = "Contraseña cambiada; hay que volver a iniciar sesión"),
        (status = 400, description = "Código incorrecto, caducado, o contraseña inválida", body = ErrorResponse),
        (status = 429, description = "Demasiados intentos", body = ErrorResponse),
    )
)]
async fn reset_password(
    State(state): State<AppState>,
    Json(dto): Json<ResetPasswordDto>,
) -> impl IntoResponse {
    match service::confirm_password_reset(&state, &dto.email, &dto.code, &dto.new_password).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(err @ AuthError::MailDisabled) => {
            crate::http_error::respond(StatusCode::SERVICE_UNAVAILABLE, err)
        }
        Err(err @ AuthError::TooManyCodeAttempts) => {
            crate::http_error::respond(StatusCode::TOO_MANY_REQUESTS, err)
        }
        Err(
            err @ (AuthError::InvalidCode | AuthError::CodeExpired | AuthError::InvalidPassword),
        ) => crate::http_error::respond(StatusCode::BAD_REQUEST, err),
        Err(err) => crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err),
    }
}
