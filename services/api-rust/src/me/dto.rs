//! Direct port of me/dto.ts. Both are PATCH bodies — every field is
//! optional, and `service.rs` only touches the fields that actually
//! came through (same as `dto.city ?? undefined` in the TS version).

use serde::{Deserialize, Deserializer};
use utoipa::ToSchema;

use crate::models::{Gender, Intention, SkillLevel, Sport};

/// Distinguishes "field absent" (`None` — leave whatever is stored) from
/// "field present and explicitly null" (`Some(None)` — clear it). Plain
/// `Option<T>` collapses both into `None`, which is fine for fields you
/// only ever set, but not for the ones a user has to be able to *unset*
/// (gender, gender preference — "prefiero no decirlo" / "cualquiera").
fn double_option<'de, T, D>(deserializer: D) -> Result<Option<Option<T>>, D::Error>
where
    T: Deserialize<'de>,
    D: Deserializer<'de>,
{
    Option::<T>::deserialize(deserializer).map(Some)
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateProfileDto {
    pub display_name: Option<String>,
    pub birth_date: Option<String>, // "YYYY-MM-DD" o ISO, igual que en TS
    /// Nombre mostrado del lugar elegido a mano (p.ej. "Málaga, España"),
    /// estilo Hinge — no viene de GPS. Se manda junto a `latitude`/
    /// `longitude`, elegidos en un buscador (Nominatim) en el cliente.
    /// See `double_option` — omitted leaves the stored value alone, an
    /// explicit `null` clears it back to "prefiero no decirlo".
    #[serde(default, deserialize_with = "double_option")]
    pub gender: Option<Option<Gender>>,
    /// A qué viene. Mismo `double_option` que `gender`: hay que poder
    /// volver a no decirlo, no sólo cambiar de opción.
    #[serde(default, deserialize_with = "double_option")]
    pub intention: Option<Option<Intention>>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    // Deliberately no `photos` here — photos are only ever managed through
    // POST/DELETE /me/photos, which enforce the MAX_PHOTOS cap and validate
    // the uploaded file. A `photos` field here would let a client overwrite
    // the array with arbitrary strings/URLs, bypassing both.
    pub sports: Option<Vec<Sport>>,
    /// Horario semanal habitual, como mapa de bits de 21 posiciones (ver
    /// `models::Profile`). `0` lo borra.
    pub availability: Option<i32>,
    /// Structured trust signals — see `models::Profile` docs. Skill level
    /// is deliberately NOT here: it lives in its own table (one row per
    /// sport) and goes through `UpdateSkillLevelsDto`/`PATCH
    /// /me/skill-levels` instead, same reasoning as photos above.
    pub years_playing: Option<i32>,
    pub club: Option<String>,
    pub achievements: Option<Vec<String>>,
    /// Running-oriented counterpart to `years_playing`/`club` — see
    /// `models::Profile` docs.
    pub avg_pace_min_per_km: Option<f64>,
    pub avg_distance_km: Option<f64>,
}

/// `PATCH /me/skill-levels` body — replaces the level for each `(sport,
/// level)` pair provided, leaves any other sport's level untouched. To
/// clear a sport's level entirely, that's a separate concern not exposed
/// yet (no product need for it so far — you'd just set a new one).
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSkillLevelsDto {
    pub levels: Vec<SkillLevelInput>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SkillLevelInput {
    pub sport: Sport,
    pub level: SkillLevel,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePreferencesDto {
    pub sports_wanted: Option<Vec<Sport>>,
    pub distance_km: Option<i32>,
    pub age_min: Option<i32>,
    pub age_max: Option<i32>,
    /// See `double_option` — an explicit `null` means "cualquiera", which
    /// is a real choice a user can go back to, not just "don't touch".
    #[serde(default, deserialize_with = "double_option")]
    pub gender_preference: Option<Option<Gender>>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct DeletePhotoDto {
    pub url: String,
}

/// Alta de un dispositivo para recibir notificaciones push.
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RegisterDeviceDto {
    /// Token de FCM que da el SDK en el móvil.
    pub token: String,
    /// `android` / `ios` / `web`. Se guarda sin validar contra una lista
    /// cerrada: sólo sirve para diagnosticar, y una plataforma nueva no
    /// debería hacer fallar el registro.
    pub platform: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UnregisterDeviceDto {
    pub token: String,
}
