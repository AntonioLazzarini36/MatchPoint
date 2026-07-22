//! Direct port of discover.service.ts.
//!
//! The Prisma version queries `User` with a nested `profile` filter and
//! then throws away any user whose profile is null. Since `profiles` is
//! its own table for us, it's simpler (and cheaper) to just query
//! `profiles` directly, joined to `users` only to exclude the current
//! user — a user without a profile row never shows up in the first place,
//! which gives the same end result as the `.filter((u) => u.profile)` in
//! the TS version.

use diesel::prelude::*;
use diesel::PgArrayExpressionMethods;
use diesel_async::RunQueryDsl;
use serde::Serialize;

use crate::models::Sport;
use crate::schema::profiles;
use crate::state::AppState;

/// Shape sent back to the client. Field names are camelCase on purpose —
/// this has to match discover.service.ts's return shape exactly, since
/// Flutter is already coded against it (and users.service.ts reuses the
/// same shape, so keep this struct in sync if that one changes too).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DiscoverProfile {
    pub user_id: String,
    pub display_name: String,
    pub birth_date: chrono::DateTime<chrono::Utc>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
}

#[derive(Debug, thiserror::Error)]
pub enum DiscoverError {
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

pub async fn discover(
    state: &AppState,
    current_user_id: &str,
    sport: Option<Sport>,
) -> Result<Vec<DiscoverProfile>, DiscoverError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| DiscoverError::Pool(e.to_string()))?;

    // Base query: everyone except me. `.into_boxed()` lets us conditionally
    // add the sport filter below without duplicating the whole query.
    let mut query = profiles::table
        .filter(profiles::user_id.ne(current_user_id))
        .into_boxed();

    if let Some(sport) = sport {
        // Postgres `@>` ("contains") — equivalent of Prisma's
        // `sports: { has: sport }` for an array column.
        query = query.filter(profiles::sports.contains(vec![sport]));
    }

    let rows = query
        .select((
            profiles::user_id,
            profiles::display_name,
            profiles::birth_date,
            profiles::city,
            profiles::bio,
            profiles::photos,
            profiles::sports,
        ))
        .limit(20)
        .load::<(
            String,
            String,
            chrono::DateTime<chrono::Utc>,
            Option<String>,
            Option<String>,
            Vec<String>,
            Vec<Sport>,
        )>(&mut conn)
        .await?;

    Ok(rows
        .into_iter()
        .map(
            |(user_id, display_name, birth_date, city, bio, photos, sports)| DiscoverProfile {
                user_id,
                display_name,
                birth_date,
                city,
                bio,
                photos,
                sports,
            },
        )
        .collect())
}
