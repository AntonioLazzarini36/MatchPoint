//! Direct port of me/dto.ts. Both are PATCH bodies — every field is
//! optional, and `service.rs` only touches the fields that actually
//! came through (same as `dto.city ?? undefined` in the TS version).

use serde::Deserialize;
use utoipa::ToSchema;

use crate::models::Sport;

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateProfileDto {
    pub display_name: Option<String>,
    pub birth_date: Option<String>, // "YYYY-MM-DD" o ISO, igual que en TS
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Option<Vec<String>>,
    pub sports: Option<Vec<Sport>>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePreferencesDto {
    pub sports_wanted: Option<Vec<Sport>>,
    pub distance_km: Option<i32>,
    pub age_min: Option<i32>,
    pub age_max: Option<i32>,
    pub gender_preference: Option<String>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct DeletePhotoDto {
    pub url: String,
}
