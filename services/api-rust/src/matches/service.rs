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

use crate::discover::service::DiscoverProfile;
use crate::models::Profile;
use crate::schema::{matches, profiles};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum MatchesError {
    #[error("Match not found")]
    NotFound,
    #[error("Not allowed")]
    Forbidden,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
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

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MatchListItem {
    pub match_id: String,
    pub created_at: DateTime<Utc>,
    pub other_user: OtherUserWithProfile,
    pub me: UserWithProfile,
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
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(String, DateTime<Utc>, String, String)>(&mut conn)
        .await?;

    let mut result = Vec::with_capacity(rows.len());

    for (match_id, created_at, user_a_id, user_b_id) in rows {
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

        result.push(MatchListItem {
            match_id,
            created_at,
            other_user: OtherUserWithProfile {
                user_id: other_id,
                profile: other_profile.map(DiscoverProfile::from),
            },
            me: UserWithProfile {
                user_id: me_id,
                profile: me_profile,
            },
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

    Ok(())
}
