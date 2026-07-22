//! Direct port of chats.service.ts.

use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::AsyncPgConnection;
use diesel_async::RunQueryDsl;
use serde::Serialize;

use crate::chats::crypto;
use crate::models::{Match, NewMessage};
use crate::schema::{matches, messages};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum ChatsError {
    #[error("Match not found")]
    MatchNotFound,
    #[error("Not allowed")]
    Forbidden,
    #[error("Message text must be between 1 and 2000 characters")]
    InvalidText,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
    #[error("Crypto error: {0}")]
    Crypto(#[from] crypto::CryptoError),
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MessageResponse {
    pub id: String,
    pub match_id: String,
    pub sender_id: String,
    pub text: String,
    pub created_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MarkReadResponse {
    pub updated: usize,
    pub read_at: DateTime<Utc>,
}

/// Equivalent of the private `assertMember` helper in chats.service.ts.
async fn assert_member(
    conn: &mut AsyncPgConnection,
    match_id: &str,
    user_id: &str,
) -> Result<Match, ChatsError> {
    let found = matches::table
        .filter(matches::id.eq(match_id))
        .first::<Match>(conn)
        .await
        .optional()?
        .ok_or(ChatsError::MatchNotFound)?;

    if found.user_a_id != user_id && found.user_b_id != user_id {
        return Err(ChatsError::Forbidden);
    }

    Ok(found)
}

pub async fn list_messages(
    state: &AppState,
    match_id: &str,
    user_id: &str,
    limit: Option<i64>,
    cursor: Option<String>,
) -> Result<Vec<MessageResponse>, ChatsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ChatsError::Pool(e.to_string()))?;

    assert_member(&mut conn, match_id, user_id).await?;

    let take = limit.unwrap_or(50).clamp(1, 100);

    let mut query = messages::table
        .filter(messages::match_id.eq(match_id))
        .into_boxed();

    if let Some(cursor) = cursor {
        if let Ok(dt) = DateTime::parse_from_rfc3339(&cursor) {
            query = query.filter(messages::created_at.lt(dt.with_timezone(&Utc)));
        }
    }

    let mut rows = query
        .order(messages::created_at.desc())
        .limit(take)
        .select((
            messages::id,
            messages::match_id,
            messages::sender_id,
            messages::ciphertext,
            messages::created_at,
            messages::read_at,
        ))
        .load::<(String, String, String, String, DateTime<Utc>, Option<DateTime<Utc>>)>(&mut conn)
        .await?;

    // We queried DESC (newest first, so LIMIT keeps the most recent N),
    // but the API returns oldest-first — same reason chats.service.ts
    // calls `rows.reverse()`.
    rows.reverse();

    let key = &state.config.message_key_base64;
    let mut result = Vec::with_capacity(rows.len());
    for (id, match_id, sender_id, ciphertext, created_at, read_at) in rows {
        let text = crypto::decrypt_text(&ciphertext, key)?;
        result.push(MessageResponse { id, match_id, sender_id, text, created_at, read_at });
    }

    Ok(result)
}

pub async fn send_message(
    state: &AppState,
    match_id: &str,
    user_id: &str,
    text: &str,
) -> Result<MessageResponse, ChatsError> {
    if text.is_empty() || text.chars().count() > 2000 {
        return Err(ChatsError::InvalidText);
    }

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ChatsError::Pool(e.to_string()))?;

    assert_member(&mut conn, match_id, user_id).await?;

    let key = &state.config.message_key_base64;
    let ciphertext = crypto::encrypt_text(text, key)?;

    let (id, match_id, sender_id, created_at, read_at) = diesel::insert_into(messages::table)
        .values(NewMessage {
            id: uuid::Uuid::new_v4().to_string(),
            match_id: match_id.to_string(),
            sender_id: user_id.to_string(),
            ciphertext,
        })
        .returning((
            messages::id,
            messages::match_id,
            messages::sender_id,
            messages::created_at,
            messages::read_at,
        ))
        .get_result::<(String, String, String, DateTime<Utc>, Option<DateTime<Utc>>)>(&mut conn)
        .await?;

    Ok(MessageResponse {
        id,
        match_id,
        sender_id,
        text: text.to_string(),
        created_at,
        read_at,
    })
}

pub async fn mark_read(
    state: &AppState,
    match_id: &str,
    user_id: &str,
) -> Result<MarkReadResponse, ChatsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ChatsError::Pool(e.to_string()))?;

    assert_member(&mut conn, match_id, user_id).await?;

    let now = Utc::now();

    let updated = diesel::update(
        messages::table
            .filter(messages::match_id.eq(match_id))
            .filter(messages::sender_id.ne(user_id))
            .filter(messages::read_at.is_null()),
    )
        .set(messages::read_at.eq(now))
        .execute(&mut conn)
        .await?;

    Ok(MarkReadResponse { updated, read_at: now })
}