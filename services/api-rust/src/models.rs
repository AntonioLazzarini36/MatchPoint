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
    device_tokens, email_verifications, matches, messages, password_resets, preferences, profiles,
    proposals, refresh_tokens, reports, session_feedback, skill_levels, swipes, users,
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
/// `PartialOrd`/`Ord` derivados a proposito: las variantes estan declaradas
/// de menor a mayor, asi que `Advanced > Intermediate` sale gratis y es lo
/// que necesita Discover para "ensename a alguien mejor que yo".
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, DbEnum, Serialize, Deserialize, ToSchema,
)]
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

/// Who the user is, as opposed to `Preferences.gender_preference` (who
/// they want to see). Nullable everywhere: stating it is optional, and
/// profiles predating the column have none. `/discover` only applies the
/// preference filter to candidates who did state one -- see
/// `discover::service` for why hiding the silent ones would be worse.
#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::Gender"]
pub enum Gender {
    #[db_rename = "MALE"]
    #[serde(rename = "MALE")]
    Male,
    #[db_rename = "FEMALE"]
    #[serde(rename = "FEMALE")]
    Female,
    #[db_rename = "OTHER"]
    #[serde(rename = "OTHER")]
    Other,
}

/// A qué viene la persona. Antes esto se preguntaba en el onboarding y la
/// frase elegida se guardaba **como la bio**, así que en toda la app sólo
/// existían tres descripciones posibles y la bio no describía a nadie. Son
/// dos datos distintos: esto es estructurado (etiqueta, y algún día filtro),
/// la bio es texto libre de la persona.
///
/// Nullable: no declararla es una respuesta válida, y los perfiles anteriores
/// a la columna no la tienen.
#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::Intention"]
pub enum Intention {
    /// Partidos serios, con marcador.
    #[db_rename = "COMPETE"]
    #[serde(rename = "COMPETE")]
    Compete,
    /// Preparar una carrera o mantenerse en forma.
    #[db_rename = "TRAIN"]
    #[serde(rename = "TRAIN")]
    Train,
    /// Busca a alguien mejor que le haga subir de nivel.
    #[db_rename = "LEARN"]
    #[serde(rename = "LEARN")]
    Learn,
    /// Sin presión, por el gusto de jugar.
    #[db_rename = "FUN"]
    #[serde(rename = "FUN")]
    Fun,
}

/// Como acabo un partido, desde el punto de vista de quien contesta: el
/// `Won` de uno es el `Lost` del otro. Se guarda asi, y no como "ganador X",
/// porque cada persona responde por su cuenta y porque es la forma que come
/// un sistema de rating.
///
/// Solo tiene sentido en deportes con marcador; al correr se queda en `None`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::SessionOutcome"]
pub enum SessionOutcome {
    #[db_rename = "WON"]
    #[serde(rename = "WON")]
    Won,
    #[db_rename = "LOST"]
    #[serde(rename = "LOST")]
    Lost,
    #[db_rename = "TIED"]
    #[serde(rename = "TIED")]
    Tied,
}

/// Lifecycle of a `Proposal`. `Cancelled` is the proposer withdrawing;
/// `Declined` is the other side saying no -- kept apart so the chat can
/// word them differently.
#[derive(Debug, Clone, Copy, PartialEq, Eq, DbEnum, Serialize, Deserialize, ToSchema)]
#[ExistingTypePath = "crate::schema::sql_types::ProposalStatus"]
pub enum ProposalStatus {
    #[db_rename = "PENDING"]
    #[serde(rename = "PENDING")]
    Pending,
    #[db_rename = "ACCEPTED"]
    #[serde(rename = "ACCEPTED")]
    Accepted,
    #[db_rename = "DECLINED"]
    #[serde(rename = "DECLINED")]
    Declined,
    #[db_rename = "CANCELLED"]
    #[serde(rename = "CANCELLED")]
    Cancelled,
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
    /// `None` = email sin verificar. Se guarda la fecha en vez de un
    /// booleano porque "cuando lo verifico" es dato util y el booleano se
    /// deduce igual (`email_verified_at.is_some()`).
    pub email_verified_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Codigo de verificacion de email, de un solo uso.
///
/// Se guarda el SHA-256 del codigo y no el codigo: si alguien lee la base
/// de datos, no puede verificar cuentas ajenas. Lo que protege un codigo
/// de 6 digitos no es el coste de hashear sino el TTL corto y el limite de
/// intentos — por eso SHA-256 y no bcrypt, que solo anadiria latencia a
/// cada intento.
#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = email_verifications)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct EmailVerification {
    pub id: String,
    pub user_id: String,
    pub code_hash: String,
    pub expires_at: DateTime<Utc>,
    pub attempts: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = email_verifications)]
pub struct NewEmailVerification {
    pub id: String,
    pub user_id: String,
    pub code_hash: String,
    pub expires_at: DateTime<Utc>,
}

/// Un código de recuperación de contraseña pendiente.
///
/// Se guarda el SHA-256 del código, no el código: mismo criterio que
/// `EmailVerification` — lo que protege seis dígitos es el plazo de vida y el
/// límite de intentos, no el coste de hashearlos.
#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = password_resets)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct PasswordReset {
    pub id: String,
    pub user_id: String,
    pub code_hash: String,
    pub expires_at: DateTime<Utc>,
    pub attempts: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = password_resets)]
pub struct NewPasswordReset {
    pub id: String,
    pub user_id: String,
    pub code_hash: String,
    pub expires_at: DateTime<Utc>,
}

/// Token de FCM de un dispositivo concreto. Una fila por dispositivo y no por
/// usuario: la misma persona puede querer que le suene en el movil y en la
/// tablet.
#[derive(Debug, Queryable, Selectable)]
#[diesel(table_name = device_tokens)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct DeviceToken {
    pub id: String,
    pub user_id: String,
    pub token: String,
    pub platform: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Lo que cada persona cuenta de una quedada ya pasada. Una fila por
/// persona y quedada — hace falta poder detectar que uno dice que se jugo y
/// el otro no.
#[derive(Debug, Queryable, Selectable, Serialize, ToSchema)]
#[diesel(table_name = session_feedback)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct SessionFeedback {
    pub id: String,
    pub proposal_id: String,
    pub user_id: String,
    pub played: bool,
    pub outcome: Option<SessionOutcome>,
    pub would_repeat: Option<bool>,
    /// Qué nivel le pareció que tenía la otra persona. Se guarda el nivel en
    /// sí y no un "correcto/mejor/peor": el veredicto se deriva al leerlo
    /// contra el nivel que esa persona declara **ahora**, así que cambiar tu
    /// nivel recoloca solas las valoraciones viejas.
    pub assessed_level: Option<SkillLevel>,
    /// La reseña se saltó. La fila existe para que la quedada no vuelva a
    /// salir en "¿qué tal fue?" eternamente, pero no afirma nada.
    pub skipped: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = session_feedback)]
pub struct NewSessionFeedback {
    pub id: String,
    pub proposal_id: String,
    pub user_id: String,
    pub played: bool,
    pub outcome: Option<SessionOutcome>,
    pub would_repeat: Option<bool>,
    pub assessed_level: Option<SkillLevel>,
    pub skipped: bool,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = device_tokens)]
pub struct NewDeviceToken {
    pub id: String,
    pub user_id: String,
    pub token: String,
    pub platform: String,
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
    pub gender: Option<Gender>,
    pub intention: Option<Intention>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
    /// Horario semanal habitual, como mapa de bits de 21 posiciones
    /// (`bit = día * 3 + franja`; día 0 = lunes, franja 0 = mañana).
    ///
    /// **Es una referencia, no una verdad**: dice lo que esa persona *suele*
    /// tener libre, para que quien vaya a proponerle algo no elija un hueco
    /// en el que nunca puede. No se usa para filtrar ni para ordenar — cuándo
    /// puede jugar alguien varía de una semana a otra, y convertir una
    /// aproximación en criterio de orden es fingir una precisión que no hay.
    ///
    /// `0` = no lo ha rellenado.
    pub availability: i32,
    /// Hinge-style: typed/picked, not device GPS. Both null until the user
    /// sets a location; `/discover`'s distance filter is skipped entirely
    /// for a viewer or candidate without coordinates.
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    /// Structured trust signals shown alongside `bio` so the other person
    /// has something concrete to judge "plays my level" on, rather than
    /// hoping it's mentioned in free text. `years_playing`/`club` read as
    /// tennis-oriented, `avg_pace_min_per_km`/`avg_distance_km` as
    /// running-oriented — the mobile client shows each pair only when the
    /// matching sport is among the user's `sports`. `achievements` is
    /// shared across whatever sports the user plays.
    pub years_playing: Option<i32>,
    pub club: Option<String>,
    pub achievements: Vec<String>,
    pub avg_pace_min_per_km: Option<f64>,
    pub avg_distance_km: Option<f64>,
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
    pub gender: Option<Gender>,
    pub intention: Option<Intention>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
    /// Horario semanal habitual, como mapa de bits de 21 posiciones
    /// (`bit = día * 3 + franja`; día 0 = lunes, franja 0 = mañana).
    ///
    /// **Es una referencia, no una verdad**: dice lo que esa persona *suele*
    /// tener libre, para que quien vaya a proponerle algo no elija un hueco
    /// en el que nunca puede. No se usa para filtrar ni para ordenar — cuándo
    /// puede jugar alguien varía de una semana a otra, y convertir una
    /// aproximación en criterio de orden es fingir una precisión que no hay.
    ///
    /// `0` = no lo ha rellenado.
    pub availability: i32,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub years_playing: Option<i32>,
    pub club: Option<String>,
    pub achievements: Vec<String>,
    pub avg_pace_min_per_km: Option<f64>,
    pub avg_distance_km: Option<f64>,
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
    pub gender_preference: Option<Gender>,
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
    pub gender_preference: Option<Gender>,
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
    /// `None` = sin revisar. Fecha y no booleano: "cuando se reviso" es dato
    /// util para responder a quien denuncio, y el booleano se deduce.
    pub reviewed_at: Option<DateTime<Utc>>,
    pub review_note: Option<String>,
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

/// A concrete plan to play, hanging off an existing `Match`. Before this
/// existed, "proposing a match" was a plain chat message — nothing to
/// accept, no state, and it scrolled away like any other text.
#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = proposals)]
#[diesel(check_for_backend(diesel::pg::Pg))]
#[serde(rename_all = "camelCase")]
pub struct Proposal {
    pub id: String,
    pub match_id: String,
    pub proposed_by_id: String,
    pub sport: Sport,
    /// Optional: a club picked from the map has a name and coordinates, a
    /// hand-typed "en el parque de al lado" has just the name, and "ya
    /// vemos dónde" has neither.
    pub place_name: Option<String>,
    pub place_lat: Option<f64>,
    pub place_lng: Option<f64>,
    pub scheduled_at: DateTime<Utc>,
    pub status: ProposalStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = proposals)]
pub struct NewProposal {
    pub id: String,
    pub match_id: String,
    pub proposed_by_id: String,
    pub sport: Sport,
    pub place_name: Option<String>,
    pub place_lat: Option<f64>,
    pub place_lng: Option<f64>,
    pub scheduled_at: DateTime<Utc>,
    pub status: ProposalStatus,
    pub updated_at: DateTime<Utc>,
}
