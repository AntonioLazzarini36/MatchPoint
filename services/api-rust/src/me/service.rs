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

use crate::discover::service::{fetch_skill_levels, SkillLevelEntry};
use crate::me::dto::{
    RegisterDeviceDto, UpdatePreferencesDto, UpdateProfileDto, UpdateSkillLevelsDto,
};
use crate::me::photos::{self, PhotoError, MAX_PHOTOS};
use crate::models::{
    NewDeviceToken, NewPreferences, NewProfile, NewUserSkillLevel, Preferences, Profile, Sport,
};
use crate::schema::{device_tokens, preferences, profiles, skill_levels, users};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum MeError {
    #[error("User not found")]
    UserNotFound,
    #[error("Profile not found — completa tu perfil antes de subir fotos")]
    ProfileNotFound,
    #[error("Ya tienes el máximo de {MAX_PHOTOS} fotos")]
    TooManyPhotos,
    #[error("Tu perfil necesita al menos 1 foto — no puedes borrar la última")]
    LastPhotoRequired,
    #[error(transparent)]
    Photo(#[from] PhotoError),
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
    #[error("{0}")]
    InvalidInput(String),
}

/// Bounds/length checks on whatever the client actually sent — fields the
/// client didn't touch (`None`) are skipped here since they either keep
/// an already-valid stored value or fall back to a known-good default
/// further down. Deliberately checked before any DB work so obviously bad
/// input fails fast with a 400 instead of a wasted round-trip.
fn validate_profile_dto(dto: &UpdateProfileDto) -> Result<(), MeError> {
    fn bad(msg: &str) -> MeError {
        MeError::InvalidInput(msg.to_string())
    }

    if let Some(name) = &dto.display_name {
        let len = name.trim().chars().count();
        if len == 0 || len > 50 {
            return Err(bad("El nombre debe tener entre 1 y 50 caracteres"));
        }
    }
    if let Some(bio) = &dto.bio {
        if bio.chars().count() > 500 {
            return Err(bad("La bio no puede superar los 500 caracteres"));
        }
    }
    if let Some(city) = &dto.city {
        if city.chars().count() > 200 {
            return Err(bad("La ciudad no puede superar los 200 caracteres"));
        }
    }
    if let Some(lat) = dto.latitude {
        if !(-90.0..=90.0).contains(&lat) {
            return Err(bad("Latitud inválida"));
        }
    }
    if let Some(lng) = dto.longitude {
        if !(-180.0..=180.0).contains(&lng) {
            return Err(bad("Longitud inválida"));
        }
    }
    if let Some(years) = dto.years_playing {
        if !(0..=100).contains(&years) {
            return Err(bad("Años jugando debe estar entre 0 y 100"));
        }
    }
    if let Some(club) = &dto.club {
        if club.chars().count() > 100 {
            return Err(bad("El club no puede superar los 100 caracteres"));
        }
    }
    if let Some(achievements) = &dto.achievements {
        if achievements.len() > 20 {
            return Err(bad("Máximo 20 logros"));
        }
        if achievements.iter().any(|a| a.chars().count() > 200) {
            return Err(bad("Cada logro debe tener como máximo 200 caracteres"));
        }
    }
    if let Some(pace) = dto.avg_pace_min_per_km {
        if !(1.0..=30.0).contains(&pace) {
            return Err(bad("El ritmo medio debe estar entre 1 y 30 min/km"));
        }
    }
    if let Some(dist) = dto.avg_distance_km {
        if !(0.0..=500.0).contains(&dist) {
            return Err(bad("La distancia media debe estar entre 0 y 500 km"));
        }
    }
    Ok(())
}

fn validate_preferences_dto(dto: &UpdatePreferencesDto) -> Result<(), MeError> {
    fn bad(msg: &str) -> MeError {
        MeError::InvalidInput(msg.to_string())
    }

    if let Some(d) = dto.distance_km {
        if !(1..=300).contains(&d) {
            return Err(bad("El radio debe estar entre 1 y 300 km"));
        }
    }
    if let Some(min) = dto.age_min {
        if !(18..=100).contains(&min) {
            return Err(bad("La edad mínima debe estar entre 18 y 100"));
        }
    }
    if let Some(max) = dto.age_max {
        if !(18..=100).contains(&max) {
            return Err(bad("La edad máxima debe estar entre 18 y 100"));
        }
    }
    // `gender_preference` needs no length check any more — it's a typed
    // enum now (was free text), so serde rejects anything that isn't one
    // of the known variants before this ever runs.
    Ok(())
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
    /// Lives outside `Profile` (its own table, one row per sport — see
    /// `models::UserSkillLevel`), so it's fetched and attached separately
    /// rather than being a column on `profile`.
    pub skill_levels: Vec<SkillLevelEntry>,
    /// Si el dueño de la cuenta ha confirmado que el email es suyo. Es un
    /// booleano y no la fecha: al cliente sólo le sirve para decidir si
    /// enseña el aviso de "verifica tu correo".
    pub email_verified: bool,
    /// Si la app deberia pedir verificar el email. Viene del servidor y no
    /// de una constante del cliente para poder encenderlo el dia que haya
    /// un dominio de correo, sin publicar una version nueva de la app.
    pub email_verification_enabled: bool,
    pub created_at: DateTime<Utc>,
}

pub async fn get_me(state: &AppState, user_id: &str) -> Result<MeResponse, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let (id, email, email_verified_at, created_at) = users::table
        .filter(users::id.eq(user_id))
        .select((
            users::id,
            users::email,
            users::email_verified_at,
            users::created_at,
        ))
        .first::<(String, String, Option<DateTime<Utc>>, DateTime<Utc>)>(&mut conn)
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

    let skill_levels = fetch_skill_levels(&mut conn, user_id).await?;

    Ok(MeResponse {
        id,
        email,
        profile,
        preferences,
        skill_levels,
        email_verified: email_verified_at.is_some(),
        email_verification_enabled: state.config.email_verification_enabled,
        created_at,
    })
}

pub async fn update_profile(
    state: &AppState,
    user_id: &str,
    dto: UpdateProfileDto,
) -> Result<Profile, MeError> {
    validate_profile_dto(&dto)?;

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

    // `Option<Option<_>>`: absent means "leave it", explicit null means
    // "clear it" (see `double_option` in dto.rs) — a user has to be able
    // to go back to not stating a gender, not just pick a different one.
    let gender = match dto.gender {
        Some(value) => value,
        None => existing.as_ref().and_then(|p| p.gender),
    };
    let city = dto
        .city
        .or_else(|| existing.as_ref().and_then(|p| p.city.clone()));
    let bio = dto
        .bio
        .or_else(|| existing.as_ref().and_then(|p| p.bio.clone()));
    let latitude = dto
        .latitude
        .or_else(|| existing.as_ref().and_then(|p| p.latitude));
    let longitude = dto
        .longitude
        .or_else(|| existing.as_ref().and_then(|p| p.longitude));
    // Not settable via this DTO — see the comment on UpdateProfileDto.
    let photos = existing
        .as_ref()
        .map(|p| p.photos.clone())
        .unwrap_or_default();
    let sports: Vec<Sport> = dto
        .sports
        .or_else(|| existing.as_ref().map(|p| p.sports.clone()))
        .unwrap_or_default();
    let years_playing = dto
        .years_playing
        .or_else(|| existing.as_ref().and_then(|p| p.years_playing));
    let club = dto
        .club
        .or_else(|| existing.as_ref().and_then(|p| p.club.clone()));
    let achievements: Vec<String> = dto
        .achievements
        .or_else(|| existing.as_ref().map(|p| p.achievements.clone()))
        .unwrap_or_default();
    let avg_pace_min_per_km = dto
        .avg_pace_min_per_km
        .or_else(|| existing.as_ref().and_then(|p| p.avg_pace_min_per_km));
    let avg_distance_km = dto
        .avg_distance_km
        .or_else(|| existing.as_ref().and_then(|p| p.avg_distance_km));

    let saved = diesel::insert_into(profiles::table)
        .values(NewProfile {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            display_name: display_name.clone(),
            birth_date,
            gender,
            city: city.clone(),
            bio: bio.clone(),
            photos: photos.clone(),
            sports: sports.clone(),
            latitude,
            longitude,
            years_playing,
            club: club.clone(),
            achievements: achievements.clone(),
            avg_pace_min_per_km,
            avg_distance_km,
            updated_at: Utc::now(),
        })
        .on_conflict(profiles::user_id)
        .do_update()
        .set((
            profiles::display_name.eq(display_name),
            profiles::birth_date.eq(birth_date),
            profiles::gender.eq(gender),
            profiles::city.eq(city),
            profiles::bio.eq(bio),
            profiles::photos.eq(photos),
            profiles::sports.eq(sports),
            profiles::latitude.eq(latitude),
            profiles::longitude.eq(longitude),
            profiles::years_playing.eq(years_playing),
            profiles::avg_pace_min_per_km.eq(avg_pace_min_per_km),
            profiles::avg_distance_km.eq(avg_distance_km),
            profiles::club.eq(club),
            profiles::achievements.eq(achievements),
            profiles::updated_at.eq(Utc::now()),
        ))
        .get_result::<Profile>(&mut conn)
        .await?;

    Ok(saved)
}

/// Upserts each `(sport, level)` pair provided — one row per sport in
/// `SkillLevel`, `ON CONFLICT (userId, sport)` so re-setting a sport's
/// level just updates it instead of erroring. Sports not mentioned in
/// `dto.levels` are left untouched. Returns the user's full current set
/// of skill levels (not just the ones just written), same "return the
/// merged state" shape as `update_profile`.
pub async fn update_skill_levels(
    state: &AppState,
    user_id: &str,
    dto: UpdateSkillLevelsDto,
) -> Result<Vec<SkillLevelEntry>, MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    for input in dto.levels {
        diesel::insert_into(skill_levels::table)
            .values(NewUserSkillLevel {
                id: uuid::Uuid::new_v4().to_string(),
                user_id: user_id.to_string(),
                sport: input.sport,
                level: input.level,
                updated_at: Utc::now(),
            })
            .on_conflict((skill_levels::user_id, skill_levels::sport))
            .do_update()
            .set((
                skill_levels::level.eq(input.level),
                skill_levels::updated_at.eq(Utc::now()),
            ))
            .execute(&mut conn)
            .await?;
    }

    Ok(fetch_skill_levels(&mut conn, user_id).await?)
}

pub async fn update_preferences(
    state: &AppState,
    user_id: &str,
    dto: UpdatePreferencesDto,
) -> Result<Preferences, MeError> {
    validate_preferences_dto(&dto)?;

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
    // Same absent-vs-null distinction as `gender` above: explicit null is
    // the user choosing "cualquiera", which has to be reachable again
    // after having picked something.
    let gender_preference = match dto.gender_preference {
        Some(value) => value,
        None => existing.as_ref().and_then(|p| p.gender_preference),
    };

    // Checked post-merge (not just against the raw DTO) since this is a
    // partial update — a request that only sends `ageMin` still has to be
    // validated against whatever `ageMax` ends up being, stored or not.
    if age_min > age_max {
        return Err(MeError::InvalidInput(
            "La edad mínima no puede ser mayor que la máxima".to_string(),
        ));
    }

    let saved = diesel::insert_into(preferences::table)
        .values(NewPreferences {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            sports_wanted: sports_wanted.clone(),
            distance_km,
            age_min,
            age_max,
            gender_preference,
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

    let had_photos = !existing.photos.is_empty();
    let updated_photos: Vec<String> = existing.photos.into_iter().filter(|p| p != url).collect();

    if had_photos && updated_photos.is_empty() {
        return Err(MeError::LastPhotoRequired);
    }

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

/// Borra la cuenta entera: usuario, perfil, swipes, matches, mensajes,
/// propuestas y fotos.
///
/// Las tablas cuelgan de `User` con `ON DELETE CASCADE`, así que una sola
/// sentencia se lleva las filas. Los **ficheros** de las fotos no los
/// borra ningún cascade — viven en disco, no en la base — así que hay que
/// quitarlos a mano antes, o quedarían huérfanos para siempre ocupando
/// sitio sin que nadie sepa de quién eran.
///
/// El borrado de ficheros es best-effort (mismo criterio que
/// `remove_photo`): si uno falla no se aborta el borrado de la cuenta, que
/// es lo que la persona ha pedido y lo que importa de verdad.
pub async fn delete_account(state: &AppState, user_id: &str) -> Result<(), MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let photos = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select(profiles::photos)
        .first::<Vec<String>>(&mut conn)
        .await
        .optional()?
        .unwrap_or_default();

    let deleted = diesel::delete(users::table.filter(users::id.eq(user_id)))
        .execute(&mut conn)
        .await?;

    if deleted == 0 {
        return Err(MeError::UserNotFound);
    }

    // Después de borrar la fila, no antes: si el borrado fallara, tendríamos
    // una cuenta viva con las fotos ya borradas del disco.
    for url in photos {
        photos::delete_photo_file(
            &url,
            &state.config.photos_dir,
            &state.config.public_base_url,
        )
        .await;
    }

    tracing::info!("cuenta borrada: {user_id}");
    Ok(())
}

/// Da de alta (o reasigna) el token de un dispositivo.
///
/// La clave está en el `ON CONFLICT (token)`: el mismo dispositivo puede
/// pasar por varias cuentas —te deslogueas y entra otra persona, o vuelves a
/// entrar con otro correo— y FCM le da **el mismo token**. Sin reasignar el
/// dueño acumularíamos filas y el usuario anterior seguiría recibiendo los
/// mensajes de la cuenta nueva en su móvil.
pub async fn register_device(
    state: &AppState,
    user_id: &str,
    dto: RegisterDeviceDto,
) -> Result<(), MeError> {
    let token = dto.token.trim().to_string();
    if token.is_empty() || token.len() > 4096 {
        return Err(MeError::InvalidInput(
            "token de dispositivo vacío o demasiado largo".into(),
        ));
    }
    let platform = dto.platform.trim().to_string();
    if platform.is_empty() || platform.len() > 32 {
        return Err(MeError::InvalidInput("plataforma inválida".into()));
    }

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    let now = Utc::now();
    diesel::insert_into(device_tokens::table)
        .values(NewDeviceToken {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            token,
            platform,
            updated_at: now,
        })
        .on_conflict(device_tokens::token)
        .do_update()
        .set((
            device_tokens::user_id.eq(user_id),
            device_tokens::updated_at.eq(now),
        ))
        .execute(&mut conn)
        .await?;

    Ok(())
}

/// Baja del token, al cerrar sesión.
///
/// Se filtra también por usuario a propósito: sin eso, cualquiera que
/// conociera un token ajeno podría dejar a otra persona sin notificaciones.
pub async fn unregister_device(
    state: &AppState,
    user_id: &str,
    token: &str,
) -> Result<(), MeError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| MeError::Pool(e.to_string()))?;

    diesel::delete(
        device_tokens::table
            .filter(device_tokens::token.eq(token))
            .filter(device_tokens::user_id.eq(user_id)),
    )
    .execute(&mut conn)
    .await?;

    Ok(())
}
