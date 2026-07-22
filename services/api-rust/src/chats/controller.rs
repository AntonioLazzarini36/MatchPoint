//! Direct port of chats.controller.ts.

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, patch},
    Json, Router,
};
use serde::Deserialize;
use serde_json::json;

use crate::auth::jwt::AuthUser;
use crate::chats::dto::SendMessageDto;
use crate::chats::service::{self, ChatsError};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/chats/:matchId/messages", get(list_messages).post(send_message))
        .route("/chats/:matchId/read", patch(mark_read))
}

#[derive(Debug, Deserialize)]
struct ListMessagesQuery {
    limit: Option<i64>,
    cursor: Option<String>,
}

async fn list_messages(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
    Query(params): Query<ListMessagesQuery>,
) -> impl IntoResponse {
    match service::list_messages(&state, &match_id, &user.user_id, params.limit, params.cursor)
        .await
    {
        Ok(messages) => Json(messages).into_response(),
        Err(err) => chats_error_response(err),
    }
}

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
    (status, Json(json!({ "message": err.to_string() }))).into_response()
}