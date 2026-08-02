//! Modelos Diesel. Sport/SwipeType son el equivalente de los `enum` de
//! schema.prisma — Postgres los guarda como enums nativos, así que usamos
//! diesel-derive-enum para mapearlos, con los valores EXACTOS que Prisma
//! ya escribió en la DB (TENNIS/RUNNING/LIKE/PASS, en mayúsculas).

use chrono::{DateTime, Utc};
use diesel::prelude::*;
use diesel_derive_enum::DbEnum;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::schema::{
    matches, messages, preferences, profiles, refresh_tokens, reports, skill_levels, swipes, users,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::Sport"]
pub enum Sport {
    #[db_rename = "TENNIS"]
    #[serde(rename = "TENNIS")]
    Tennis,
    #[db_rename = "RUNNING"]
    #[serde(rename = "RUNNING")]
    Running,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::SwipeType"]
pub enum SwipeType {
    #[db_rename = "LIKE"]
    #[serde(rename = "LIKE")]
    Like,
    #[db_rename = "PASS"]
    #[serde(rename = "PASS")]
    Pass,
}

/// Self-reported, not computed — there's no Elo/Glicko rating yet (see
/// status.md). One of these exists per (user, sport) in `SkillLevel`, not
/// as a single scalar on `Profile`, since a player can be at a different
/// level in each sport they play.
#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::SkillLevelValue"]
pub enum SkillLevel {
    #[db_rename = "BEGINNER"]
    #[serde(rename = "BEGINNER")]
    Beginner,
    #[db_rename = "INTERMEDIATE"]
    #[serde(rename = "INTERMEDIATE")]
    Intermediate,
    #[db_rename = "ADVANCED"]
    #[serde(rename = "ADVANCED")]
    Advanced,
    #[db_rename = "COMPETITIVE"]
    #[serde(rename = "COMPETITIVE")]
    Competitive,
}

#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = users)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: String,
    pub email: String,
    #[serde(skip_serializing)]
    pub password_hash: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = users)]
pub struct NewUser<'a> {
    pub id: String,
    pub email: &'a str,
    pub password_hash: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Queryable, Selectable, Serialize, ToSchema)]
#[diesel(table_name = profiles)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Profile {
    pub id: String,
    pub user_id: String,
    pub display_name: String,
    pub birth_date: DateTime<Utc>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
    /// Hinge-style: typed/picked, not device GPS. Both null until the user
    /// sets a location; `/discover`'s distance filter is skipped entirely
    /// for a viewer or candidate without coordinates.
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    /// Structured trust signals shown alongside `bio` so the other person
    /// has something concrete to judge "plays my level" on, rather than
    /// hoping it's mentioned in free text.
    pub years_playing: Option<i32>,
    pub club: Option<String>,
    pub achievements: Vec<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = profiles)]
pub struct NewProfile {
    pub id: String,
    pub user_id: String,
    pub display_name: String,
    pub birth_date: DateTime<Utc>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub years_playing: Option<i32>,
    pub club: Option<String>,
    pub achievements: Vec<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Queryable, Selectable, Serialize, ToSchema)]
#[diesel(table_name = preferences)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Preferences {
    pub id: String,
    pub user_id: String,
    pub sports_wanted: Vec<Sport>,
    pub distance_km: i32,
    pub age_min: i32,
    pub age_max: i32,
    pub gender_preference: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = preferences)]
pub struct NewPreferences {
    pub id: String,
    pub user_id: String,
    pub sports_wanted: Vec<Sport>,
    pub distance_km: i32,
    pub age_min: i32,
    pub age_max: i32,
    pub gender_preference: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = refresh_tokens)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct RefreshToken {
    pub id: String,
    pub user_id: String,
    pub token_hash: String,
    pub revoked_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = refresh_tokens)]
pub struct NewRefreshToken {
    pub id: String,
    pub user_id: String,
    pub token_hash: String,
}

#[derive(Debug, Queryable, Selectable, Serialize)]
#[diesel(table_name = swipes)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Swipe {
    pub id: String,
    pub from_user_id: String,
    pub to_user_id: String,
    pub sport: Sport,
    pub swipe_type: SwipeType,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = swipes)]
pub struct NewSwipe {
    pub id: String,
    pub from_user_id: String,
    pub to_user_id: String,
    pub sport: Sport,
    pub swipe_type: SwipeType,
}

#[derive(Debug, Queryable, Selectable, Serialize)]
#[diesel(table_name = matches)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Match {
    pub id: String,
    pub user_a_id: String,
    pub user_b_id: String,
    pub sport: Sport,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = matches)]
pub struct NewMatch {
    pub id: String,
    pub user_a_id: String,
    pub user_b_id: String,
    pub sport: Sport,
}

#[derive(Debug, Queryable, Selectable, Serialize)]
#[diesel(table_name = messages)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Message {
    pub id: String,
    pub match_id: String,
    pub sender_id: String,
    pub ciphertext: String,
    pub created_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = messages)]
pub struct NewMessage {
    pub id: String,
    pub match_id: String,
    pub sender_id: String,
    pub ciphertext: String,
}

#[derive(Debug, Queryable, Selectable, Serialize)]
#[diesel(table_name = reports)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Report {
    pub id: String,
    pub reporter_user_id: String,
    pub reported_user_id: String,
    pub reason: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = reports)]
pub struct NewReport {
    pub id: String,
    pub reporter_user_id: String,
    pub reported_user_id: String,
    pub reason: String,
}

/// Named `UserSkillLevel` (not `SkillLevel`, which is the level enum
/// above) — one row per (user, sport).
#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = skill_levels)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct UserSkillLevel {
    pub id: String,
    pub user_id: String,
    pub sport: Sport,
    pub level: SkillLevel,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = skill_levels)]
pub struct NewUserSkillLevel {
    pub id: String,
    pub user_id: String,
    pub sport: Sport,
    pub level: SkillLevel,
    pub updated_at: DateTime<Utc>,
}
