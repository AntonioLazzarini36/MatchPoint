//! Direct port of users.service.ts.
//!
//! Reuses `DiscoverProfile` from the discover module — users.service.ts
//! itself comments that its return shape is "similar to DiscoverProfile"
//! on purpose, so instead of duplicating the struct we just import it.

use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;

use crate::discover::service::{age_from_birth_date, fetch_skill_levels, DiscoverProfile};
use crate::models::NewReport;
use crate::schema::{profiles, reports};
use crate::state::AppState;

#[derive(thiserror::Error, Debug)]
pub enum UsersError {
    #[error("Profile not found")]
    ProfileNotFound,
    #[error("Cannot report yourself")]
    CannotTargetSelf,
    #[error("Reason must be between 1 and 1000 characters")]
    InvalidReason,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

pub async fn get_profile(state: &AppState, user_id: &str) -> Result<DiscoverProfile, UsersError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| UsersError::Pool(e.to_string()))?;

    let row = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select((
            profiles::user_id,
            profiles::display_name,
            profiles::birth_date,
            profiles::gender,
            profiles::city,
            profiles::bio,
            profiles::photos,
            profiles::sports,
            profiles::years_playing,
            profiles::club,
            profiles::achievements,
            profiles::avg_pace_min_per_km,
            profiles::avg_distance_km,
        ))
        .first::<(
            String,
            String,
            chrono::DateTime<chrono::Utc>,
            Option<crate::models::Gender>,
            Option<String>,
            Option<String>,
            Vec<String>,
            Vec<crate::models::Sport>,
            Option<i32>,
            Option<String>,
            Vec<String>,
            Option<f64>,
            Option<f64>,
        )>(&mut conn)
        .await
        .optional()?
        .ok_or(UsersError::ProfileNotFound)?;

    let (
        user_id,
        display_name,
        birth_date,
        gender,
        city,
        bio,
        photos,
        sports,
        years_playing,
        club,
        achievements,
        avg_pace_min_per_km,
        avg_distance_km,
    ) = row;
    let skill_levels = fetch_skill_levels(&mut conn, &user_id).await?;

    Ok(DiscoverProfile {
        user_id,
        display_name,
        age: age_from_birth_date(birth_date),
        gender,
        city,
        bio,
        photos,
        sports,
        years_playing,
        club,
        avg_pace_min_per_km,
        avg_distance_km,
        achievements,
        skill_levels,
    })
}

/// A propósito NO borra el match — reportar es solo dejar constancia para
/// revisión. Si además quieres cortar todo contacto, eso es un unmatch
/// aparte (`DELETE /matches/:matchId`), acción explícita del usuario.
pub async fn report_user(
    state: &AppState,
    reporter_id: &str,
    reported_id: &str,
    reason: &str,
) -> Result<(), UsersError> {
    if reporter_id == reported_id {
        return Err(UsersError::CannotTargetSelf);
    }
    if reason.trim().is_empty() || reason.chars().count() > 1000 {
        return Err(UsersError::InvalidReason);
    }

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| UsersError::Pool(e.to_string()))?;

    diesel::insert_into(reports::table)
        .values(NewReport {
            id: uuid::Uuid::new_v4().to_string(),
            reporter_user_id: reporter_id.to_string(),
            reported_user_id: reported_id.to_string(),
            reason: reason.to_string(),
        })
        .execute(&mut conn)
        .await?;

    Ok(())
}
