use serde::Deserialize;
use utoipa::ToSchema;

use crate::models::{Gender, Intention, Sport};

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RegisterDto {
    pub email: String,
    pub password: String,

    pub display_name: Option<String>,
    pub birth_date: Option<String>, // ISO o "YYYY-MM-DD", igual que en TS
    pub gender: Option<Gender>,
    /// A qué viene. Se manda ya en el registro porque el onboarding lo
    /// pregunta antes de crear la cuenta (el wizard entero se envía junto).
    pub intention: Option<Intention>,

    pub city: Option<String>,
    pub bio: Option<String>,

    #[serde(default)]
    pub sports: Option<Vec<Sport>>,
    #[serde(default)]
    pub sports_wanted: Option<Vec<Sport>>,
    pub distance_km: Option<i32>,
    pub age_min: Option<i32>,
    pub age_max: Option<i32>,
    pub gender_preference: Option<Gender>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct LoginDto {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RefreshDto {
    pub refresh_token: String,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct LogoutDto {
    pub refresh_token: String,
}
