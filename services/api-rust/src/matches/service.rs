//! Direct port of matches.service.ts.
//!
//! The TS version does one Prisma query with nested `userA`/`userB`
//! includes (a self-join on User). Diesel can do that too, but only via
//! `diesel::alias!`, which is a good deal more machinery than anything
//! we've used so far. For an MVP-sized `take(50)`, doing one extra
//! `SELECT` per side per match is simpler to write correctly and fast
//! enough — this is the "explicit N+1" tradeoff mentioned when we
//! planned this module out.

use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::chats::crypto;
use crate::discover::service::{fetch_skill_levels, DiscoverProfile};
use crate::models::{Profile, Sport, SwipeType};
use crate::schema::{matches, messages, profiles, proposals, session_feedback, swipes};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum MatchesError {
    #[error("No encontramos ese match")]
    NotFound,
    #[error("No tienes acceso a esto")]
    Forbidden,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
    #[error("Crypto error: {0}")]
    Crypto(#[from] crypto::CryptoError),
}

/// The authenticated user's own side of a match — full `Profile`
/// (including `birth_date`) is fine here, same reasoning as `/me`.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UserWithProfile {
    pub user_id: String,
    pub profile: Option<Profile>,
}

/// The other side of a match — `DiscoverProfile` (age, not exact
/// birth_date), same PII reasoning as `/discover` and `/users/:userId`.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct OtherUserWithProfile {
    pub user_id: String,
    pub profile: Option<DiscoverProfile>,
}

/// Decrypted preview of the most recent message in a match, for the
/// matches list — same shape as `chats::service::MessageResponse` minus
/// the fields the list screen doesn't need.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct LastMessagePreview {
    pub sender_id: String,
    pub text: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MatchListItem {
    pub match_id: String,
    pub created_at: DateTime<Utc>,
    pub sport: Sport,
    pub other_user: OtherUserWithProfile,
    pub me: UserWithProfile,
    /// `None` when nobody has sent a message in this match yet.
    pub last_message: Option<LastMessagePreview>,
    /// Messages sent by the other side that `me` hasn't read yet (via
    /// `PATCH /chats/:matchId/read`).
    pub unread_count: i64,
    /// Cuántas veces habéis jugado ya, según lo que habéis contado tras cada
    /// quedada.
    ///
    /// Es la señal de confianza más fuerte que tiene la app, porque es la
    /// única que **no se puede inflar**: el nivel se auto-declara y los
    /// logros se escriben a mano, pero esto sale de dos personas
    /// confirmando por separado que quedaron y jugaron.
    ///
    /// Se cuenta una quedada si **cualquiera de los dos** dijo que se jugó:
    /// exigir que lo confirmen ambos haría que la mitad de los partidos
    /// reales no contaran, sólo porque alguien no abrió la app.
    pub played_together: i64,
}

pub async fn list(state: &AppState, user_id: &str) -> Result<Vec<MatchListItem>, MatchesError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MatchesError::Pool(e.to_string()))?;

    let rows = matches::table
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .order(matches::created_at.desc())
        .limit(50)
        .select((
            matches::id,
            matches::created_at,
            matches::sport,
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(String, DateTime<Utc>, Sport, String, String)>(&mut conn)
        .await?;

    let mut result = Vec::with_capacity(rows.len());

    for (match_id, created_at, sport, user_a_id, user_b_id) in rows {
        let is_a = user_a_id == user_id;
        let (me_id, other_id) = if is_a {
            (user_a_id, user_b_id)
        } else {
            (user_b_id, user_a_id)
        };

        let me_profile = profiles::table
            .filter(profiles::user_id.eq(&me_id))
            .first::<Profile>(&mut conn)
            .await
            .optional()?;

        let other_profile = profiles::table
            .filter(profiles::user_id.eq(&other_id))
            .first::<Profile>(&mut conn)
            .await
            .optional()?;
        let other_skill_levels = fetch_skill_levels(&mut conn, &other_id).await?;

        let last_message_row = messages::table
            .filter(messages::match_id.eq(&match_id))
            .order(messages::created_at.desc())
            .select((
                messages::sender_id,
                messages::ciphertext,
                messages::created_at,
            ))
            .first::<(String, String, DateTime<Utc>)>(&mut conn)
            .await
            .optional()?;
        let last_message = match last_message_row {
            Some((sender_id, ciphertext, created_at)) => Some(LastMessagePreview {
                sender_id,
                text: crypto::decrypt_text(&ciphertext, &state.config.message_key_base64)?,
                created_at,
            }),
            None => None,
        };

        let unread_count: i64 = messages::table
            .filter(messages::match_id.eq(&match_id))
            .filter(messages::sender_id.ne(&me_id))
            .filter(messages::read_at.is_null())
            .count()
            .get_result(&mut conn)
            .await?;

        let played_together: i64 = proposals::table
            .inner_join(session_feedback::table.on(session_feedback::proposal_id.eq(proposals::id)))
            .filter(proposals::match_id.eq(&match_id))
            .filter(session_feedback::played.eq(true))
            .select(proposals::id)
            .distinct()
            .count()
            .get_result(&mut conn)
            .await?;

        result.push(MatchListItem {
            match_id,
            created_at,
            sport,
            other_user: OtherUserWithProfile {
                user_id: other_id,
                profile: other_profile.map(|p| DiscoverProfile {
                    skill_levels: other_skill_levels,
                    ..DiscoverProfile::from(p)
                }),
            },
            me: UserWithProfile {
                user_id: me_id,
                profile: me_profile,
            },
            last_message,
            unread_count,
            played_together,
        });
    }

    Ok(result)
}

/// Deshace un match — borra la fila (los mensajes se van con ella, la FK
/// de `Message.matchId` tiene `ON DELETE CASCADE`). Solo un miembro del
/// match puede deshacerlo.
pub async fn unmatch(state: &AppState, match_id: &str, user_id: &str) -> Result<(), MatchesError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MatchesError::Pool(e.to_string()))?;

    let found = matches::table
        .filter(matches::id.eq(match_id))
        .select((matches::user_a_id, matches::user_b_id))
        .first::<(String, String)>(&mut conn)
        .await
        .optional()?
        .ok_or(MatchesError::NotFound)?;

    if found.0 != user_id && found.1 != user_id {
        return Err(MatchesError::Forbidden);
    }

    diesel::delete(matches::table.filter(matches::id.eq(match_id)))
        .execute(&mut conn)
        .await?;

    // Los LIKE que provocaron el match pasan a PASS con fecha de hoy.
    //
    // Borrar el match no tocaba los swipes, y un LIKE esconde a alguien del
    // feed **para siempre**: deshacer un match dejaba a las dos personas
    // mutuamente invisibles el resto de su vida en la app. Con la densidad
    // real que hay eso es tirar oferta a la basura, y encima castiga a quien
    // no deshizo nada. Convertidos en PASS caducan como cualquier descarte
    // (`discover::service::PASS_EXPIRES_AFTER_DAYS`): ninguno de los dos
    // vuelve a ver al otro ahora mismo — que es lo que se pidió al deshacer
    // el match — pero dentro de un mes se pueden volver a cruzar. Para
    // cortar de verdad y para siempre está Reportar, que es lo que revisa
    // una persona.
    diesel::update(
        swipes::table.filter(
            swipes::from_user_id
                .eq(&found.0)
                .and(swipes::to_user_id.eq(&found.1))
                .or(swipes::from_user_id
                    .eq(&found.1)
                    .and(swipes::to_user_id.eq(&found.0))),
        ),
    )
    .set((
        swipes::swipe_type.eq(SwipeType::Pass),
        swipes::created_at.eq(chrono::Utc::now()),
    ))
    .execute(&mut conn)
    .await?;

    Ok(())
}
