//! Direct port of discover.service.ts.
//!
//! The Prisma version queries `User` with a nested `profile` filter and
//! then throws away any user whose profile is null. Since `profiles` is
//! its own table for us, it's simpler (and cheaper) to just query
//! `profiles` directly, joined to `users` only to exclude the current
//! user — a user without a profile row never shows up in the first place,
//! which gives the same end result as the `.filter((u) => u.profile)` in
//! the TS version.

use chrono::{DateTime, Datelike, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel::PgArrayExpressionMethods;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::models::Sport;
use crate::schema::{preferences, profiles, swipes};
use crate::state::AppState;

/// Shape sent back to the client. Field names are camelCase on purpose —
/// this has to match discover.service.ts's return shape exactly, since
/// Flutter is already coded against it (and users.service.ts reuses the
/// same shape, so keep this struct in sync if that one changes too).
///
/// `age` instead of `birth_date`: this struct goes out to *other* users
/// (`/discover`, `/users/:userId/profile`, and the `otherUser` side of
/// `/matches`), so exact date of birth is PII that has no business leaving
/// the server — only `/me` (and the `me` side of `/matches`) returns the
/// raw `birth_date` (via `Profile`, to the owner of that data).
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct DiscoverProfile {
    pub user_id: String,
    pub display_name: String,
    pub age: i32,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
}

impl From<crate::models::Profile> for DiscoverProfile {
    fn from(p: crate::models::Profile) -> Self {
        DiscoverProfile {
            user_id: p.user_id,
            display_name: p.display_name,
            age: age_from_birth_date(p.birth_date),
            city: p.city,
            bio: p.bio,
            photos: p.photos,
            sports: p.sports,
        }
    }
}

/// Age in whole years as of now, from a stored `birth_date`.
pub fn age_from_birth_date(birth_date: chrono::DateTime<chrono::Utc>) -> i32 {
    let now = chrono::Utc::now();
    let mut age = now.year() - birth_date.year();
    if (now.month(), now.day()) < (birth_date.month(), birth_date.day()) {
        age -= 1;
    }
    age
}

/// `now` shifted back `years` years, clamping Feb 29 to Feb 28 on
/// non-leap target years. Used to turn an age bound into a `birth_date`
/// bound the DB can filter on directly.
fn years_ago(now: DateTime<Utc>, years: i32) -> DateTime<Utc> {
    let year = now.year() - years;
    let mut day = now.day();
    loop {
        if let Some(date) = chrono::NaiveDate::from_ymd_opt(year, now.month(), day) {
            return date.and_time(now.time()).and_utc();
        }
        day -= 1;
    }
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

    // Gente a la que ya di LIKE o PASS (para el deporte pedido, si se
    // pidió uno) no debe volver a aparecer — ni siquiera tras un unmatch,
    // que solo borra el Match, no el Swipe que lo originó.
    let mut swiped_query = swipes::table
        .filter(swipes::from_user_id.eq(current_user_id))
        .into_boxed();
    if let Some(sport) = sport {
        swiped_query = swiped_query.filter(swipes::sport.eq(sport));
    }
    let excluded_ids: Vec<String> = swiped_query
        .select(swipes::to_user_id)
        .load(&mut conn)
        .await?;

    // `distance_km`/`gender_preference` aren't applied: profiles have no
    // stored coordinates and no gender field to filter against yet
    // (tracked separately — see status.md), so only age is enforceable
    // today.
    let age_range = preferences::table
        .filter(preferences::user_id.eq(current_user_id))
        .select((preferences::age_min, preferences::age_max))
        .first::<(i32, i32)>(&mut conn)
        .await
        .optional()?;
    let (age_min, age_max) = age_range.unwrap_or((18, 60));

    let now = Utc::now();
    // birth_date <= this means "at least age_min years old".
    let max_birth_date = years_ago(now, age_min);
    // birth_date > this means "at most age_max years old".
    let min_birth_date = years_ago(now, age_max + 1);

    // Base query: everyone except me. `.into_boxed()` lets us conditionally
    // add the sport filter below without duplicating the whole query.
    let mut query = profiles::table
        .filter(profiles::user_id.ne(current_user_id))
        .filter(profiles::user_id.ne_all(excluded_ids))
        .filter(profiles::birth_date.le(max_birth_date))
        .filter(profiles::birth_date.gt(min_birth_date))
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
                age: age_from_birth_date(birth_date),
                city,
                bio,
                photos,
                sports,
            },
        )
        .collect())
}
