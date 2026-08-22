//! Direct port of chats.controller.ts.

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{get, patch, post},
    Json, Router,
};
use serde::Deserialize;

use crate::auth::jwt::AuthUser;
use crate::auth::rate_limit;
use crate::chats::dto::SendMessageDto;
use crate::chats::service::{self, ChatsError};
#[allow(unused_imports)] // referenced only inside #[utoipa::path] responses(body = ...)
use crate::chats::service::{MarkReadResponse, MessageResponse};
#[allow(unused_imports)]
use crate::openapi::ErrorResponse;
use crate::state::AppState;

pub fn router(state: AppState) -> Router<AppState> {
    // El limite es solo para enviar. Leer el chat lo hace el sondeo cada 4 s
    // y marcarlo como leido va detras de cada lectura: limitarlos romperia
    // el uso normal.
    let limited = Router::new()
        .route("/chats/:matchId/messages", post(send_message))
        .route_layer(middleware::from_fn_with_state(
            state,
            rate_limit::limit_messages,
        ));

    Router::new()
        .route("/chats/:matchId/messages", get(list_messages))
        .route("/chats/:matchId/read", patch(mark_read))
        .merge(limited)
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct ListMessagesQuery {
    limit: Option<i64>,
    cursor: Option<String>,
}

#[utoipa::path(
    get,
    path = "/chats/{matchId}/messages",
    tag = "chats",
    security(("bearerAuth" = [])),
    params(
        ("matchId" = String, Path, description = "Id del match"),
        ListMessagesQuery,
    ),
    responses(
        (status = 200, description = "Mensajes del match, descifrados", body = Vec<MessageResponse>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres miembro de este match", body = ErrorResponse),
        (status = 404, description = "Match no encontrado", body = ErrorResponse),
    )
)]
async fn list_messages(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
    Query(params): Query<ListMessagesQuery>,
) -> impl IntoResponse {
    match service::list_messages(
        &state,
        &match_id,
        &user.user_id,
        params.limit,
        params.cursor,
    )
    .await
    {
        Ok(messages) => Json(messages).into_response(),
        Err(err) => chats_error_response(err),
    }
}

#[utoipa::path(
    post,
    path = "/chats/{matchId}/messages",
    tag = "chats",
    security(("bearerAuth" = [])),
    params(("matchId" = String, Path, description = "Id del match")),
    request_body = SendMessageDto,
    responses(
        (status = 200, description = "Mensaje enviado", body = MessageResponse),
        (status = 400, description = "Texto vacío o demasiado largo (1-2000 chars)", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres miembro de este match", body = ErrorResponse),
        (status = 404, description = "Match no encontrado", body = ErrorResponse),
    )
)]
async fn send_message(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
    Json(dto): Json<SendMessageDto>,
) -> impl IntoResponse {
    match service::send_message(&state, &match_id, &user.user_id, &dto.text).await {
        Ok(message) => Json(message).into_response(),
        Err(err) => chats_error_response(err),
    }
}

#[utoipa::path(
    patch,
    path = "/chats/{matchId}/read",
    tag = "chats",
    security(("bearerAuth" = [])),
    params(("matchId" = String, Path, description = "Id del match")),
    responses(
        (status = 200, description = "Mensajes marcados como leídos", body = MarkReadResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres miembro de este match", body = ErrorResponse),
        (status = 404, description = "Match no encontrado", body = ErrorResponse),
    )
)]
async fn mark_read(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
) -> impl IntoResponse {
    match service::mark_read(&state, &match_id, &user.user_id).await {
        Ok(result) => Json(result).into_response(),
        Err(err) => chats_error_response(err),
    }
}

fn chats_error_response(err: ChatsError) -> axum::response::Response {
    let status = match &err {
        ChatsError::MatchNotFound => StatusCode::NOT_FOUND,
        ChatsError::Forbidden => StatusCode::FORBIDDEN,
        ChatsError::InvalidText => StatusCode::BAD_REQUEST,
        ChatsError::Db(_) | ChatsError::Pool(_) | ChatsError::Crypto(_) => {
            tracing::error!("chats error: {err}");
            StatusCode::INTERNAL_SERVER_ERROR
        }
    };
    crate::http_error::respond(status, err)
}
