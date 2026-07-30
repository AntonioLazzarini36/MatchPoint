//! Direct port of me.service.ts.
//!
//! `update_profile`/`update_preferences` are upserts in Prisma
//! (`prisma.profile.upsert`), and critically a *partial* one — a field
//! not present in the DTO leaves the existing DB value untouched. Diesel
//! doesn't have a built-in "only set the fields that were provided"
//! upsert, so we replicate the behavior explicitly: fetch the existing
//! row (if any), fold the DTO on top of it in Rust, then write the
//! merged result. Less magic than the Prisma one-liner, but byte-for-byte
//! the same end behavior.

use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::me::dto::{UpdatePreferencesDto, UpdateProfileDto};
use crate::me::photos::{self, PhotoError, MAX_PHOTOS};
use crate::models::{NewPreferences, NewProfile, Preferences, Profile, Sport};
use crate::schema::{preferences, profiles, users};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum MeError {
    #[error("User not found")]
    UserNotFound,
    #[error("Profile not found — completa tu perfil antes de subir fotos")]
    ProfileNotFound,
    #[error("Ya tienes el máximo de {MAX_PHOTOS} fotos")]
    TooManyPhotos,
    #[error(transparent)]
    Photo(#[from] PhotoError),
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

/// Mirrors exactly what me.service.ts's `getMe` selects — note the TS
/// version only returns `createdAt`, not `updatedAt`, so we keep this as
/// its own struct instead of reusing the full `User` model.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MeResponse {
    pub id: String,
    pub email: String,
    pub profile: Option<Profile>,
    pub preferences: Option<Preferences>,
    pub created_at: DateTime<Utc>,
}

pub async fn get_me(state: &AppState, user_id: &str) -> Result<MeResponse, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let (id, email, created_at) = users::table
        .filter(users::id.eq(user_id))
        .select((users::id, users::email, users::created_at))
        .first::<(String, String, DateTime<Utc>)>(&mut conn)
        .await
        .optional()?
        .ok_or(MeError::UserNotFound)?;

    let profile = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .first::<Profile>(&mut conn)
        .await
        .optional()?;

    let preferences = preferences::table
        .filter(preferences::user_id.eq(user_id))
        .first::<Preferences>(&mut conn)
        .await
        .optional()?;

    Ok(MeResponse {
        id,
        email,
        profile,
        preferences,
        created_at,
    })
}

pub async fn update_profile(
    state: &AppState,
    user_id: &str,
    dto: UpdateProfileDto,
) -> Result<Profile, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let existing = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .first::<Profile>(&mut conn)
        .await
        .optional()?;

    // Same defaults as the TS `create:` branch of the upsert when there's
    // no existing row yet; same "keep old value if not provided" as the
    // `update:` branch otherwise.
    let display_name = dto
        .display_name
        .or_else(|| existing.as_ref().map(|p| p.display_name.clone()))
        .unwrap_or_else(|| "Unknown".to_string());

    let birth_date = dto
        .birth_date
        .as_deref()
        .map(parse_date)
        .or_else(|| existing.as_ref().map(|p| p.birth_date))
        .unwrap_or_else(|| parse_date("2000-01-01"));

    let city = dto
        .city
        .or_else(|| existing.as_ref().and_then(|p| p.city.clone()));
    let bio = dto
        .bio
        .or_else(|| existing.as_ref().and_then(|p| p.bio.clone()));
    let photos = dto
        .photos
        .or_else(|| existing.as_ref().map(|p| p.photos.clone()))
        .unwrap_or_default();
    let sports: Vec<Sport> = dto
        .sports
        .or_else(|| existing.as_ref().map(|p| p.sports.clone()))
        .unwrap_or_default();

    let saved = diesel::insert_into(profiles::table)
        .values(NewProfile {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            display_name: display_name.clone(),
            birth_date,
            city: city.clone(),
            bio: bio.clone(),
            photos: photos.clone(),
            sports: sports.clone(),
            updated_at: Utc::now(),
        })
        .on_conflict(profiles::user_id)
        .do_update()
        .set((
            profiles::display_name.eq(display_name),
            profiles::birth_date.eq(birth_date),
            profiles::city.eq(city),
            profiles::bio.eq(bio),
            profiles::photos.eq(photos),
            profiles::sports.eq(sports),
            profiles::updated_at.eq(Utc::now()),
        ))
        .get_result::<Profile>(&mut conn)
        .await?;

    Ok(saved)
}

pub async fn update_preferences(
    state: &AppState,
    user_id: &str,
    dto: UpdatePreferencesDto,
) -> Result<Preferences, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let existing = preferences::table
        .filter(preferences::user_id.eq(user_id))
        .first::<Preferences>(&mut conn)
        .await
        .optional()?;

    let sports_wanted: Vec<Sport> = dto
        .sports_wanted
        .or_else(|| existing.as_ref().map(|p| p.sports_wanted.clone()))
        .unwrap_or_default();
    let distance_km = dto
        .distance_km
        .or_else(|| existing.as_ref().map(|p| p.distance_km))
        .unwrap_or(25);
    let age_min = dto
        .age_min
        .or_else(|| existing.as_ref().map(|p| p.age_min))
        .unwrap_or(18);
    let age_max = dto
        .age_max
        .or_else(|| existing.as_ref().map(|p| p.age_max))
        .unwrap_or(60);
    let gender_preference = dto
        .gender_preference
        .or_else(|| existing.as_ref().and_then(|p| p.gender_preference.clone()));

    let saved = diesel::insert_into(preferences::table)
        .values(NewPreferences {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            sports_wanted: sports_wanted.clone(),
            distance_km,
            age_min,
            age_max,
            gender_preference: gender_preference.clone(),
            updated_at: Utc::now(),
        })
        .on_conflict(preferences::user_id)
        .do_update()
        .set((
            preferences::sports_wanted.eq(sports_wanted),
            preferences::distance_km.eq(distance_km),
            preferences::age_min.eq(age_min),
            preferences::age_max.eq(age_max),
            preferences::gender_preference.eq(gender_preference),
            preferences::updated_at.eq(Utc::now()),
        ))
        .get_result::<Preferences>(&mut conn)
        .await?;

    Ok(saved)
}

pub async fn add_photo(
    state: &AppState,
    user_id: &str,
    multipart: axum::extract::Multipart,
) -> Result<Profile, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let existing = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .first::<Profile>(&mut conn)
        .await
        .optional()?
        .ok_or(MeError::ProfileNotFound)?;

    if existing.photos.len() >= MAX_PHOTOS {
        return Err(MeError::TooManyPhotos);
    }

    let url = photos::save_uploaded_photo(
        multipart,
        &state.config.photos_dir,
        &state.config.public_base_url,
    )
    .await?;

    let mut updated_photos = existing.photos;
    updated_photos.push(url);

    let saved = diesel::update(profiles::table.filter(profiles::user_id.eq(user_id)))
        .set((
            profiles::photos.eq(updated_photos),
            profiles::updated_at.eq(Utc::now()),
        ))
        .get_result::<Profile>(&mut conn)
        .await?;

    Ok(saved)
}

pub async fn remove_photo(state: &AppState, user_id: &str, url: &str) -> Result<Profile, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let existing = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .first::<Profile>(&mut conn)
        .await
        .optional()?
        .ok_or(MeError::ProfileNotFound)?;

    let updated_photos: Vec<String> = existing.photos.into_iter().filter(|p| p != url).collect();

    let saved = diesel::update(profiles::table.filter(profiles::user_id.eq(user_id)))
        .set((
            profiles::photos.eq(updated_photos),
            profiles::updated_at.eq(Utc::now()),
        ))
        .get_result::<Profile>(&mut conn)
        .await?;

    photos::delete_photo_file(url, &state.config.photos_dir, &state.config.public_base_url).await;

    Ok(saved)
}

fn parse_date(s: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&Utc))
        .unwrap_or_else(|_| {
            chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d")
                .expect("invalid birthDate format")
                .and_hms_opt(0, 0, 0)
                .unwrap()
                .and_utc()
        })
}
