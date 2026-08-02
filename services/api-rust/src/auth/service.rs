use base64::{engine::general_purpose::STANDARD, Engine as _};
use chrono::Utc;
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::scoped_futures::ScopedFutureExt;
use diesel_async::AsyncConnection;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use sha2::{Digest, Sha256};
use utoipa::ToSchema;

use crate::auth::dto::{LoginDto, RegisterDto};
use crate::auth::jwt::{self, Claims};
use crate::models::{NewPreferences, NewProfile, NewRefreshToken, NewUser};
use crate::schema::{preferences, profiles, refresh_tokens, users};
use crate::state::AppState;

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AuthTokens {
    pub user_id: String,
    pub access_token: String,
    pub refresh_token: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct EmailAvailability {
    pub available: bool,
}

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("Email already in use")]
    EmailInUse,
    #[error("Invalid credentials")]
    InvalidCredentials,
    #[error("Missing refresh token")]
    MissingRefreshToken,
    #[error("Invalid refresh token")]
    InvalidRefreshToken,
    #[error("Refresh token revoked")]
    RefreshTokenRevoked,
    #[error("Refresh token mismatch")]
    RefreshTokenMismatch,
    #[error("User not found")]
    UserNotFound,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

/// bcrypt only looks at the first 72 bytes of its input. Two refresh JWTs
/// for the same user share an identical prefix (header + `sub` + `email`
/// claims) well past that limit — only `exp`, positioned near the end of
/// the payload, differs — so bcrypt-hashing the raw token would make
/// every refresh token ever issued to a user verify as equal, silently
/// defeating rotation (an old, supposedly-replaced token would keep
/// working). Pre-hashing with SHA-256 collapses each distinct token to a
/// fixed 64-char hex digest before bcrypt ever sees it, so the 72-byte
/// window covers the whole thing and different tokens can't collide.
fn refresh_token_digest(refresh_token: &str) -> String {
    STANDARD.encode(Sha256::digest(refresh_token.as_bytes()))
}

async fn issue_tokens(
    state: &AppState,
    user_id: &str,
    email: &str,
) -> Result<(String, String), AuthError> {
    let cfg = &state.config;
    let now = Utc::now().timestamp() as usize;

    let access_claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        exp: now + cfg.jwt_access_expires_in_seconds as usize,
    };
    let refresh_claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        exp: now + cfg.jwt_refresh_expires_in_seconds as usize,
    };

    let access_token = jwt::sign(&access_claims, &cfg.jwt_access_secret);
    let refresh_token = jwt::sign(&refresh_claims, &cfg.jwt_refresh_secret);

    let token_hash = bcrypt::hash(refresh_token_digest(&refresh_token), bcrypt::DEFAULT_COST)
        .expect("bcrypt should not fail");

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AuthError::Pool(e.to_string()))?;

    // MVP: 1 refresh activo por usuario (limpiamos los anteriores) — igual que auth.service.ts
    diesel::delete(refresh_tokens::table.filter(refresh_tokens::user_id.eq(user_id)))
        .execute(&mut conn)
        .await?;

    diesel::insert_into(refresh_tokens::table)
        .values(NewRefreshToken {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            token_hash,
        })
        .execute(&mut conn)
        .await?;

    Ok((access_token, refresh_token))
}

/// Consulta pública (sin auth) para que el frontend compruebe el email
/// *antes* de meter al usuario en todo el wizard de onboarding — evita
/// descubrir "email ya en uso" al final, después de rellenar todo.
pub async fn email_available(state: &AppState, email: &str) -> Result<bool, AuthError> {
    let email = email.trim().to_lowercase();

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AuthError::Pool(e.to_string()))?;

    let existing = users::table
        .filter(users::email.eq(&email))
        .select(users::id)
        .first::<String>(&mut conn)
        .await
        .optional()?;

    Ok(existing.is_none())
}

pub async fn register(state: &AppState, dto: RegisterDto) -> Result<AuthTokens, AuthError> {
    let email = dto.email.trim().to_lowercase();

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AuthError::Pool(e.to_string()))?;

    let existing = users::table
        .filter(users::email.eq(&email))
        .select(users::id)
        .first::<String>(&mut conn)
        .await
        .optional()?;

    if existing.is_some() {
        return Err(AuthError::EmailInUse);
    }

    let password_hash =
        bcrypt::hash(&dto.password, bcrypt::DEFAULT_COST).expect("bcrypt should not fail");
    let user_id = uuid::Uuid::new_v4().to_string();

    let tx_user_id = user_id.clone();
    let tx_email = email.clone();

    // The three writes below (User, optionally Profile, Preferences) need
    // to succeed or fail together — otherwise a failure partway through
    // (like the missing `updatedAt` bug we hit earlier) leaves a User row
    // with no Preferences attached, same as it did with test11@test.com.
    conn.transaction::<_, AuthError, _>(|conn| {
        async move {
            diesel::insert_into(users::table)
                .values(NewUser {
                    id: tx_user_id.clone(),
                    email: &tx_email,
                    password_hash,
                    updated_at: Utc::now(),
                })
                .execute(conn)
                .await?;

            if let (Some(display_name), Some(birth_date)) = (&dto.display_name, &dto.birth_date) {
                diesel::insert_into(profiles::table)
                    .values(NewProfile {
                        id: uuid::Uuid::new_v4().to_string(),
                        user_id: tx_user_id.clone(),
                        display_name: display_name.clone(),
                        birth_date: parse_date(birth_date),
                        city: dto.city.clone(),
                        bio: dto.bio.clone(),
                        photos: vec![],
                        sports: dto.sports.clone().unwrap_or_default(),
                        // Not part of RegisterDto — set afterwards via the
                        // same PATCH /me/profile call the mobile onboarding
                        // flow already makes right after registering.
                        latitude: None,
                        longitude: None,
                        years_playing: None,
                        club: None,
                        achievements: vec![],
                        avg_pace_min_per_km: None,
                        avg_distance_km: None,
                        updated_at: Utc::now(),
                    })
                    .execute(conn)
                    .await?;
            }

            diesel::insert_into(preferences::table)
                .values(NewPreferences {
                    id: uuid::Uuid::new_v4().to_string(),
                    user_id: tx_user_id.clone(),
                    sports_wanted: dto.sports_wanted.clone().unwrap_or_default(),
                    distance_km: dto.distance_km.unwrap_or(25),
                    age_min: dto.age_min.unwrap_or(18),
                    age_max: dto.age_max.unwrap_or(60),
                    gender_preference: dto.gender_preference.clone(),
                    updated_at: Utc::now(),
                })
                .execute(conn)
                .await?;

            Ok(())
        }
        .scope_boxed()
    })
    .await?;

    drop(conn);

    let (access_token, refresh_token) = issue_tokens(state, &user_id, &email).await?;
    Ok(AuthTokens {
        user_id,
        access_token,
        refresh_token,
    })
}

pub async fn login(state: &AppState, dto: LoginDto) -> Result<AuthTokens, AuthError> {
    let email = dto.email.trim().to_lowercase();

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AuthError::Pool(e.to_string()))?;

    let (user_id, password_hash) = users::table
        .filter(users::email.eq(&email))
        .select((users::id, users::password_hash))
        .first::<(String, String)>(&mut conn)
        .await
        .optional()?
        .ok_or(AuthError::InvalidCredentials)?;

    drop(conn);

    if !bcrypt::verify(&dto.password, &password_hash).unwrap_or(false) {
        return Err(AuthError::InvalidCredentials);
    }

    let (access_token, refresh_token) = issue_tokens(state, &user_id, &email).await?;
    Ok(AuthTokens {
        user_id,
        access_token,
        refresh_token,
    })
}

pub async fn refresh(state: &AppState, refresh_token: &str) -> Result<AuthTokens, AuthError> {
    if refresh_token.is_empty() {
        return Err(AuthError::MissingRefreshToken);
    }

    let claims = jwt::verify(refresh_token, &state.config.jwt_refresh_secret)
        .map_err(|_| AuthError::InvalidRefreshToken)?;

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| AuthError::Pool(e.to_string()))?;

    let stored = refresh_tokens::table
        .filter(refresh_tokens::user_id.eq(&claims.sub))
        .filter(refresh_tokens::revoked_at.is_null())
        .order(refresh_tokens::created_at.desc())
        .select(refresh_tokens::token_hash)
        .first::<String>(&mut conn)
        .await
        .optional()?
        .ok_or(AuthError::RefreshTokenRevoked)?;

    if !bcrypt::verify(refresh_token_digest(refresh_token), &stored).unwrap_or(false) {
        return Err(AuthError::RefreshTokenMismatch);
    }

    let user_email = users::table
        .filter(users::id.eq(&claims.sub))
        .select(users::email)
        .first::<String>(&mut conn)
        .await
        .optional()?
        .ok_or(AuthError::UserNotFound)?;

    drop(conn);

    let (access_token, refresh_token) = issue_tokens(state, &claims.sub, &user_email).await?;
    Ok(AuthTokens {
        user_id: claims.sub,
        access_token,
        refresh_token,
    })
}

pub async fn logout(state: &AppState, refresh_token: &str) -> Result<(), AuthError> {
    if refresh_token.is_empty() {
        return Ok(());
    }

    if let Ok(claims) = jwt::verify(refresh_token, &state.config.jwt_refresh_secret) {
        if let Ok(mut conn) = state.db.get().await {
            let _ = diesel::update(
                refresh_tokens::table
                    .filter(refresh_tokens::user_id.eq(&claims.sub))
                    .filter(refresh_tokens::revoked_at.is_null()),
            )
            .set(refresh_tokens::revoked_at.eq(Some(Utc::now())))
            .execute(&mut conn)
            .await;
        }
    }

    Ok(())
}

fn parse_date(s: &str) -> chrono::DateTime<Utc> {
    chrono::DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&Utc))
        .unwrap_or_else(|_| {
            chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d")
                .expect("invalid birthDate format")
                .and_hms_opt(0, 0, 0)
                .unwrap()
                .and_utc()
        })
}
