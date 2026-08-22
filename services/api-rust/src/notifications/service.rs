use chrono::{Duration, Utc};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::models::ProposalStatus;
use crate::schema::{matches, messages, proposals, session_feedback};
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
    /// Quedadas ya pasadas de las que no has contado todavía qué ocurrió.
    /// Sin este contador, cerrar el bucle dependería de que a alguien se le
    /// ocurriera entrar a mirar, que es justo lo que no pasa.
    pub sessions_to_confirm: i64,
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

    // Mismo criterio que `proposals::service::list_awaiting_feedback`: solo
    // las aceptadas, ya pasadas con margen, del ultimo mes y sin contestar
    // por mi. Si los dos criterios se separan, el badge dira un numero y la
    // pantalla ensenara otro.
    let cutoff = Utc::now() - Duration::hours(3);
    let floor = Utc::now() - Duration::days(30);
    let already_answered = session_feedback::table
        .filter(session_feedback::user_id.eq(user_id))
        .select(session_feedback::proposal_id);

    let sessions_to_confirm: i64 = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .filter(proposals::status.eq(ProposalStatus::Accepted))
        .filter(proposals::scheduled_at.lt(cutoff))
        .filter(proposals::scheduled_at.ge(floor))
        .filter(proposals::id.ne_all(already_answered))
        .count()
        .get_result(&mut conn)
        .await?;

    Ok(NotificationCounts {
        unread_messages,
        pending_proposals,
        sessions_to_confirm,
    })
}
