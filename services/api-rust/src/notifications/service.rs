use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::models::ProposalStatus;
use crate::schema::{matches, messages, proposals};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum NotificationsError {
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct NotificationCounts {
    /// Mensajes sin leer que te ha mandado la otra parte, sumando todos
    /// tus matches.
    pub unread_messages: i64,
    /// Propuestas pendientes esperando TU respuesta — las que hiciste tú
    /// no cuentan, porque no hay nada que hacer con ellas.
    pub pending_proposals: i64,
}

pub async fn counts(
    state: &AppState,
    user_id: &str,
) -> Result<NotificationCounts, NotificationsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| NotificationsError::Pool(e.to_string()))?;

    let unread_messages: i64 = messages::table
        .inner_join(matches::table.on(matches::id.eq(messages::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .filter(messages::sender_id.ne(user_id))
        .filter(messages::read_at.is_null())
        .count()
        .get_result(&mut conn)
        .await?;

    let pending_proposals: i64 = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .filter(proposals::status.eq(ProposalStatus::Pending))
        .filter(proposals::proposed_by_id.ne(user_id))
        .count()
        .get_result(&mut conn)
        .await?;

    Ok(NotificationCounts {
        unread_messages,
        pending_proposals,
    })
}
