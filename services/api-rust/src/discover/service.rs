//! Direct port of discover.service.ts.
//!
//! The Prisma version queries `User` with a nested `profile` filter and
//! then throws away any user whose profile is null. Since `profiles` is
//! its own table for us, it's simpler (and cheaper) to just query
//! `profiles` directly, joined to `users` only to exclude the current
//! user — a user without a profile row never shows up in the first place,
//! which gives the same end result as the `.filter((u) => u.profile)` in
//! the TS version.

use std::collections::{HashMap, HashSet};

use chrono::{DateTime, Datelike, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel::PgArrayExpressionMethods;
use diesel_async::AsyncPgConnection;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::models::{Gender, Intention, SkillLevel, Sport, SwipeType};
use crate::schema::{preferences, profiles, skill_levels, swipes};
use crate::state::AppState;

/// One self-reported level for one sport — see `models::SkillLevel` and
/// status.md for why this isn't a computed rating yet.
#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SkillLevelEntry {
    pub sport: Sport,
    pub level: SkillLevel,
}

/// Every level a user has set, across all their sports. Shared by
/// `discover`, `users::service::get_profile`, and the "other side" of a
/// match — anywhere a `DiscoverProfile` is built for someone other than
/// the caller.
pub async fn fetch_skill_levels(
    conn: &mut AsyncPgConnection,
    user_id: &str,
) -> Result<Vec<SkillLevelEntry>, diesel::result::Error> {
    let rows = skill_levels::table
        .filter(skill_levels::user_id.eq(user_id))
        .select((skill_levels::sport, skill_levels::level))
        .load::<(Sport, SkillLevel)>(conn)
        .await?;

    Ok(rows
        .into_iter()
        .map(|(sport, level)| SkillLevelEntry { sport, level })
        .collect())
}

/// Same as `fetch_skill_levels` but batched for many users at once — used
/// by `discover`, which would otherwise do one extra query per candidate.
async fn fetch_skill_levels_for(
    conn: &mut AsyncPgConnection,
    user_ids: &[String],
) -> Result<HashMap<String, Vec<SkillLevelEntry>>, diesel::result::Error> {
    let rows = skill_levels::table
        .filter(skill_levels::user_id.eq_any(user_ids))
        .select((
            skill_levels::user_id,
            skill_levels::sport,
            skill_levels::level,
        ))
        .load::<(String, Sport, SkillLevel)>(conn)
        .await?;

    let mut by_user: HashMap<String, Vec<SkillLevelEntry>> = HashMap::new();
    for (user_id, sport, level) in rows {
        by_user
            .entry(user_id)
            .or_default()
            .push(SkillLevelEntry { sport, level });
    }
    Ok(by_user)
}

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
    /// Stating it is optional, so `None` genuinely means "prefiero no
    /// decirlo" and the client shows nothing rather than guessing.
    pub gender: Option<Gender>,
    /// A qué viene. Misma visibilidad que `bio`/`sports`: es justo la señal
    /// que hace decidir si merece la pena deslizar.
    pub intention: Option<Intention>,
    pub city: Option<String>,
    pub bio: Option<String>,
    pub photos: Vec<String>,
    pub sports: Vec<Sport>,
    /// Structured trust signals — same visibility tier as `bio`/`sports`
    /// (public to anyone who can see this profile at all), not as private
    /// as exact `birth_date`.
    pub years_playing: Option<i32>,
    pub club: Option<String>,
    pub achievements: Vec<String>,
    pub avg_pace_min_per_km: Option<f64>,
    pub avg_distance_km: Option<f64>,
    /// Self-reported, one entry per sport the user plays. Empty when
    /// `DiscoverProfile` is built via `From<Profile>` without a DB
    /// connection on hand — callers that need it populated (discover,
    /// users::get_profile, matches list) fetch it separately and
    /// overwrite this field.
    pub skill_levels: Vec<SkillLevelEntry>,
    /// Straight-line distance from the viewer, in km, rounded to one
    /// decimal. `None` when either side has no coordinates — which in
    /// `/discover` only happens for a viewer who hasn't set a location,
    /// since candidates without one are filtered out entirely.
    ///
    /// The raw coordinates never leave the server (same call as
    /// `birth_date` → `age`); this is the derived number a card can show.
    pub distance_km: Option<f64>,
    /// True when this person's self-reported level in the sport being
    /// browsed is the same as the viewer's. Computed here because the
    /// server already needs it to order the feed, and it saves every
    /// client fetching its own levels just to re-derive it.
    pub matches_your_level: bool,
    /// True when this person already swiped LIKE on the viewer, so a like
    /// back is an instant match.
    ///
    /// Only ever `true` inside `/discover` (everywhere else it defaults to
    /// false): it is the viewer's own inbound interest, not a public
    /// property of the profile, so it must not leak from
    /// `/users/:userId/profile` or the `otherUser` side of `/matches`.
    pub likes_you: bool,
}

impl From<crate::models::Profile> for DiscoverProfile {
    fn from(p: crate::models::Profile) -> Self {
        DiscoverProfile {
            user_id: p.user_id,
            display_name: p.display_name,
            age: age_from_birth_date(p.birth_date),
            gender: p.gender,
            intention: p.intention,
            city: p.city,
            bio: p.bio,
            photos: p.photos,
            sports: p.sports,
            years_playing: p.years_playing,
            club: p.club,
            achievements: p.achievements,
            avg_pace_min_per_km: p.avg_pace_min_per_km,
            avg_distance_km: p.avg_distance_km,
            skill_levels: Vec::new(),
            distance_km: None,
            matches_your_level: false,
            likes_you: false,
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

/// Great-circle distance in km between two lat/lng points. No PostGIS/
/// earthdistance extension set up, so this runs in Rust over an
/// already-fetched candidate set rather than in the SQL query.
fn haversine_km(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    const EARTH_RADIUS_KM: f64 = 6371.0;
    let d_lat = (lat2 - lat1).to_radians();
    let d_lng = (lng2 - lng1).to_radians();
    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (d_lng / 2.0).sin().powi(2);
    EARTH_RADIUS_KM * 2.0 * a.sqrt().asin()
}

#[derive(Debug, thiserror::Error)]
pub enum DiscoverError {
    #[error("Tú no juegas a ese deporte")]
    SportNotYours,
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

    // Los deportes propios mandan sobre lo que se pida por query.
    //
    // El filtro por deporte se aplicaba solo a los **candidatos**: pedir
    // `?sport=RUNNING` sin correr devolvía corredores igualmente, y de ahí
    // salían matches entre gente sin ningún deporte en común — un match
    // que no puede terminar en ninguna quedada, porque proponer exige que
    // los dos practiquen ese deporte.
    let my_sports = profiles::table
        .filter(profiles::user_id.eq(current_user_id))
        .select(profiles::sports)
        .first::<Vec<Sport>>(&mut conn)
        .await
        .optional()?
        .unwrap_or_default();

    if let Some(requested) = sport {
        // Sin perfil todavía (lista vacía) no se bloquea: no hay dato con
        // el que contradecir, y quien no ha terminado el onboarding
        // tampoco tiene nada que descubrir.
        if !my_sports.is_empty() && !my_sports.contains(&requested) {
            return Err(DiscoverError::SportNotYours);
        }
    }

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

    // `distance_km` is applied against the viewer's own hand-picked
    // coordinates (see `me/dto.rs` — Hinge-style, not device GPS), and
    // `gender_preference` is applied against `Profile.gender` (added
    // 2026-08-04 — before that this setting existed but silently did
    // nothing, since there was no gender stored to compare against).
    let prefs = preferences::table
        .filter(preferences::user_id.eq(current_user_id))
        .select((
            preferences::age_min,
            preferences::age_max,
            preferences::distance_km,
            preferences::gender_preference,
        ))
        .first::<(i32, i32, i32, Option<Gender>)>(&mut conn)
        .await
        .optional()?;
    let (age_min, age_max, distance_km, gender_preference) = prefs.unwrap_or((18, 60, 25, None));

    // No coordinates set -> nothing to filter by distance with, so every
    // candidate passes regardless of `distance_km` (same "not enforceable
    // yet for this viewer" spirit as the age fallback above).
    let my_location = profiles::table
        .filter(profiles::user_id.eq(current_user_id))
        .select((profiles::latitude, profiles::longitude))
        .first::<(Option<f64>, Option<f64>)>(&mut conn)
        .await
        .optional()?
        .and_then(|(lat, lng)| lat.zip(lng));

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
        // Perfil incompleto = perfil que no se enseña. Sin foto no hay
        // nada que mirar, y sin coordenadas no se puede decir a qué
        // distancia está — las dos cosas convierten una tarjeta en un
        // hueco vacío que sólo sirve para descartar.
        //
        // Ojo, esto es un cambio deliberado de criterio respecto al filtro
        // de distancia de más abajo ("no castigues al que no ha rellenado
        // algo"): entonces la ubicación era opcional en el onboarding y
        // exigirla habría vaciado el feed. Ahora el onboarding no deja
        // pasar del paso de ubicación ni terminar sin al menos una foto,
        // así que un perfil sin ellas es de una cuenta a medio crear, no
        // alguien a quien se esté castigando.
        .filter(profiles::photos.ne(Vec::<String>::new()))
        .filter(profiles::latitude.is_not_null())
        .filter(profiles::longitude.is_not_null())
        .into_boxed();

    if let Some(wanted) = gender_preference {
        // Candidates who never stated a gender are deliberately kept in.
        // Same call as the distance filter's "no coordinates -> not
        // filtered": most profiles predate this column, and silently
        // emptying someone's feed the moment they set a preference is a
        // worse failure than showing a few unlabelled profiles.
        query = query.filter(profiles::gender.eq(wanted).or(profiles::gender.is_null()));
    }

    if let Some(sport) = sport {
        // Postgres `@>` ("contains") — equivalent of Prisma's
        // `sports: { has: sport }` for an array column.
        query = query.filter(profiles::sports.contains(vec![sport]));
    } else if !my_sports.is_empty() {
        // Sin `?sport=`, se enseña a quien comparta **alguno** de los tuyos
        // (`&&`, "se solapan"), no a todo el mundo.
        query = query.filter(profiles::sports.overlaps_with(my_sports.clone()));
    }

    // When we'll need to filter by distance afterwards (in Rust, no
    // PostGIS), fetch a larger candidate pool up front — otherwise the
    // SQL-side LIMIT could hand us 20 rows that all get filtered out by
    // distance and we'd return fewer results than actually exist.
    let fetch_limit: i64 = if my_location.is_some() { 200 } else { 20 };

    let rows = query
        .select((
            profiles::user_id,
            profiles::display_name,
            profiles::birth_date,
            profiles::gender,
            profiles::intention,
            profiles::city,
            profiles::bio,
            profiles::photos,
            profiles::sports,
            profiles::latitude,
            profiles::longitude,
            profiles::years_playing,
            profiles::club,
            profiles::achievements,
            profiles::avg_pace_min_per_km,
            profiles::avg_distance_km,
        ))
        .limit(fetch_limit)
        .load::<(
            String,
            String,
            chrono::DateTime<chrono::Utc>,
            Option<Gender>,
            Option<Intention>,
            Option<String>,
            Option<String>,
            Vec<String>,
            Vec<Sport>,
            Option<f64>,
            Option<f64>,
            Option<i32>,
            Option<String>,
            Vec<String>,
            Option<f64>,
            Option<f64>,
        )>(&mut conn)
        .await?;

    let mut result: Vec<DiscoverProfile> = rows
        .into_iter()
        .filter_map(
            |(
                user_id,
                display_name,
                birth_date,
                gender,
                intention,
                city,
                bio,
                photos,
                sports,
                lat,
                lng,
                years_playing,
                club,
                achievements,
                avg_pace_min_per_km,
                avg_distance_km,
            )| {
                // La distancia se calcula una vez y sirve para dos cosas:
                // descartar a quien queda fuera del radio y decirle al
                // cliente a cuanto esta el resto. Antes se calculaba solo
                // para filtrar y se tiraba, asi que la tarjeta no podia
                // decir "a 4 km" aunque el dato ya estuviera hecho.
                let distance = match (my_location, lat.zip(lng)) {
                    (Some((my_lat, my_lng)), Some((lat, lng))) => {
                        let km = haversine_km(my_lat, my_lng, lat, lng);
                        if km > distance_km as f64 {
                            return None;
                        }
                        Some((km * 10.0).round() / 10.0)
                    }
                    // Un viewer sin coordenadas no puede filtrar por
                    // distancia — ve a todo el mundo, sin cifra. (El caso
                    // contrario ya no existe: los candidatos sin
                    // coordenadas quedan fuera de la consulta.)
                    _ => None,
                };

                Some(DiscoverProfile {
                    user_id,
                    display_name,
                    age: age_from_birth_date(birth_date),
                    gender,
                    intention,
                    city,
                    bio,
                    photos,
                    sports,
                    years_playing,
                    club,
                    avg_pace_min_per_km,
                    avg_distance_km,
                    achievements,
                    skill_levels: Vec::new(),
                    distance_km: distance,
                    matches_your_level: false,
                    likes_you: false,
                })
            },
        )
        .collect();

    result.truncate(40);

    // One batched query for skill levels instead of one per candidate.
    let ids: Vec<String> = result.iter().map(|p| p.user_id.clone()).collect();
    let mut skill_levels_by_user = fetch_skill_levels_for(&mut conn, &ids).await?;
    for profile in &mut result {
        profile.skill_levels = skill_levels_by_user
            .remove(&profile.user_id)
            .unwrap_or_default();
    }

    // Quién te ha dado LIKE ya. Una sola consulta para todos los
    // candidatos, no una por tarjeta.
    // Sin filtrar por deporte, igual que el match: un like es "quiero
    // jugar contigo". Filtrarlo aqui hacia que la chapa "te ha dado like"
    // apareciera o no segun que feed estuvieras mirando, con la misma
    // persona — y que a veces prometiera un match que luego no saltaba.
    let liked_me: HashSet<String> = swipes::table
        .filter(swipes::to_user_id.eq(current_user_id))
        .filter(swipes::from_user_id.eq_any(&ids))
        .filter(swipes::swipe_type.eq(SwipeType::Like))
        .select(swipes::from_user_id)
        .load::<String>(&mut conn)
        .await?
        .into_iter()
        .collect();
    for profile in &mut result {
        profile.likes_you = liked_me.contains(&profile.user_id);
    }

    // Orden con intención, en vez del que devuelva Postgres: primero
    // quien ya te ha dado like (un like tuyo cierra el match al instante),
    // luego quien juega a tu mismo nivel en el deporte que estás mirando
    // — que es la promesa de la app, encontrar con quién jugar de tu
    // nivel, no la cara que salga antes en la tabla.
    // Lista, no `HashMap`: `Sport` no implementa `Hash` (es un enum de
    // Diesel) y de todas formas son dos deportes.
    let my_levels = fetch_skill_levels(&mut conn, current_user_id).await?;
    let my_level_for_sport = sport.and_then(|s| {
        my_levels
            .iter()
            .find(|entry| entry.sport == s)
            .map(|entry| (s, entry.level))
    });

    for profile in &mut result {
        profile.matches_your_level = my_level_for_sport
            .map(|(s, mine)| {
                profile
                    .skill_levels
                    .iter()
                    .any(|entry| entry.sport == s && entry.level == mine)
            })
            .unwrap_or(false);
    }

    result.sort_by_key(
        |profile| match (profile.likes_you, profile.matches_your_level) {
            (true, _) => 0,
            (false, true) => 1,
            (false, false) => 2,
        },
    );

    result.truncate(20);

    Ok(result)
}
