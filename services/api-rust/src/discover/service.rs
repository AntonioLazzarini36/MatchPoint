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
    /// Horario semanal habitual, como mapa de bits (ver `models::Profile`).
    /// Se expone para poder enseñarlo al proponer una quedada; **no** se usa
    /// para filtrar ni ordenar.
    pub availability: i32,
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
    /// Los huecos del horario semanal que esta persona y el que mira
    /// tienen **en común**, como el mismo mapa de bits de 21 posiciones
    /// que `availability`. `0` = no coinciden en nada (o alguno de los dos
    /// no lo ha rellenado).
    ///
    /// Es relativo a quien mira, igual que `distance_km` y `likes_you`, y
    /// por lo tanto vale `0` fuera de `/discover`: en
    /// `/users/:userId/profile` no hay "el otro" contra el que cruzarlo.
    pub shared_availability: i32,
    /// Cuántos huecos son esos. Derivado de `shared_availability`, pero se
    /// manda hecho porque es lo que la lista enseña ("coincidís en 3
    /// huecos") y ordena.
    pub shared_slots: i32,
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
            availability: p.availability,
            years_playing: p.years_playing,
            club: p.club,
            achievements: p.achievements,
            avg_pace_min_per_km: p.avg_pace_min_per_km,
            avg_distance_km: p.avg_distance_km,
            skill_levels: Vec::new(),
            distance_km: None,
            matches_your_level: false,
            likes_you: false,
            shared_availability: 0,
            shared_slots: 0,
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

/// Cuánto tarda un PASS en dejar de esconder a alguien.
///
/// Un PASS era permanente, y con la densidad real de la app eso vacía el
/// feed para siempre: en una ciudad con treinta personas que juegan al
/// tenis, dos tardes deslizando y no queda nadie — nunca más. Un "hoy no"
/// no es "nunca", así que caduca. El LIKE sí es permanente: o acabó en
/// match (y entonces se habla por el chat, no por el feed) o la otra
/// persona todavía puede corresponderlo.
pub const PASS_EXPIRES_AFTER_DAYS: i64 = 30;

/// Lo que se le pide al feed. Antes era un `Option<Sport>` suelto; ahora
/// son tres cosas y una tupla de tres `Option` en la firma no se lee.
#[derive(Debug, Clone, Copy, Default)]
pub struct DiscoverFilters {
    pub sport: Option<Sport>,
    /// Mapa de bits de 21 posiciones (mismo formato que
    /// `Profile.availability`): sólo sale quien tenga **algún** hueco
    /// marcado dentro de esta máscara. `None` o `0` = sin filtrar.
    pub availability: Option<i32>,
    /// Sólo gente con este nivel declarado en el deporte que se mira.
    pub level: Option<SkillLevel>,
}

impl DiscoverFilters {
    pub fn for_sport(sport: Sport) -> Self {
        Self {
            sport: Some(sport),
            ..Self::default()
        }
    }
}

/// Cuántos bits tiene puestos una máscara de disponibilidad.
fn slot_count(mask: i32) -> i32 {
    mask.count_ones() as i32
}

pub async fn discover(
    state: &AppState,
    current_user_id: &str,
    filters: DiscoverFilters,
) -> Result<Vec<DiscoverProfile>, DiscoverError> {
    let DiscoverFilters {
        sport,
        availability: wanted_availability,
        level: wanted_level,
    } = filters;
    // Un `0` no filtra nada (todo el mundo tiene algún bit fuera de él, y
    // `x & 0 == 0` dejaría el feed vacío), así que se trata como "sin
    // filtro" en vez de como "nadie".
    let wanted_availability = wanted_availability.filter(|mask| *mask != 0);
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

    // Gente a la que ya deslicé y que por tanto no debe volver a salir.
    //
    // El LIKE esconde para siempre; el PASS sólo durante
    // `PASS_EXPIRES_AFTER_DAYS` (ver esa constante). El `created_at` que
    // cuenta es el del último deslizamiento: `create_swipe` lo reescribe al
    // hacer upsert, así que volver a pasar de alguien reinicia su plazo en
    // vez de arrastrar la fecha del primer descarte.
    let pass_cutoff = Utc::now() - chrono::Duration::days(PASS_EXPIRES_AFTER_DAYS);
    let mut swiped_query = swipes::table
        .filter(swipes::from_user_id.eq(current_user_id))
        .filter(
            swipes::swipe_type
                .eq(SwipeType::Like)
                .or(swipes::created_at.gt(pass_cutoff)),
        )
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
    let me = profiles::table
        .filter(profiles::user_id.eq(current_user_id))
        .select((
            profiles::latitude,
            profiles::longitude,
            profiles::availability,
            profiles::intention,
        ))
        .first::<(Option<f64>, Option<f64>, i32, Option<Intention>)>(&mut conn)
        .await
        .optional()?;
    let my_location = me.and_then(|(lat, lng, _, _)| lat.zip(lng));
    let my_availability = me.map(|(_, _, availability, _)| availability).unwrap_or(0);
    // A qué vengo yo, para poder comparar (ver `goal_fit`).
    let my_intention = me.and_then(|(_, _, _, intention)| intention);

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

    // Distancia, disponibilidad y nivel se filtran en Rust (no hay PostGIS,
    // y las dos últimas son operaciones de bits / de otra tabla), así que
    // hay que traer un lote holgado: un LIMIT ajustado en SQL podría
    // devolver 20 filas que se caen todas en esos filtros y dejar el feed
    // vacío teniendo gente de sobra detrás.
    const FETCH_LIMIT: i64 = 200;

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
            profiles::availability,
            profiles::latitude,
            profiles::longitude,
            profiles::years_playing,
            profiles::club,
            profiles::achievements,
            profiles::avg_pace_min_per_km,
            profiles::avg_distance_km,
        ))
        .limit(FETCH_LIMIT)
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
            i32,
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
                availability,
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

                // Filtro explícito de "cuándo puedo jugar": basta con
                // coincidir en **un** hueco. Quien no ha rellenado su
                // horario (`availability == 0`) sí se queda fuera cuando se
                // pide este filtro, y a propósito: la pregunta que hizo el
                // que mira es "¿quién puede el sábado?", y de esa persona
                // no se sabe. No es el mismo caso que el género o las
                // coordenadas, donde el dato que falta no contradice nada.
                if let Some(mask) = wanted_availability {
                    if availability & mask == 0 {
                        return None;
                    }
                }

                let shared_availability = availability & my_availability;

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
                    availability,
                    years_playing,
                    club,
                    avg_pace_min_per_km,
                    avg_distance_km,
                    achievements,
                    skill_levels: Vec::new(),
                    distance_km: distance,
                    matches_your_level: false,
                    likes_you: false,
                    shared_availability,
                    shared_slots: slot_count(shared_availability),
                })
            },
        )
        .collect();

    // One batched query for skill levels instead of one per candidate.
    let ids: Vec<String> = result.iter().map(|p| p.user_id.clone()).collect();
    let mut skill_levels_by_user = fetch_skill_levels_for(&mut conn, &ids).await?;
    for profile in &mut result {
        profile.skill_levels = skill_levels_by_user
            .remove(&profile.user_id)
            .unwrap_or_default();
    }

    // Filtro explícito de nivel. Va después de traer los niveles porque
    // viven en otra tabla; sólo tiene sentido con un deporte concreto
    // pedido, que es como lo usa el cliente (el nivel es *por deporte*).
    if let (Some(level), Some(sport)) = (wanted_level, sport) {
        result.retain(|profile| {
            profile
                .skill_levels
                .iter()
                .any(|entry| entry.sport == sport && entry.level == level)
        });
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

    // Orden con intención, en vez del que devuelva Postgres. Ver el
    // `sort_by_key` de abajo para el criterio y por qué.
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

    result.sort_by_key(|profile| {
        // 1. Quien ya te dio like: tu like cierra el match al instante.
        // 2. Con quién puedes coincidir de verdad — ver `overlap_rank`.
        // 3. Quien encaja con lo que buscas (ver `goal_fit`).
        // 4. Lo demas, por cercania.
        (
            !profile.likes_you,
            std::cmp::Reverse(overlap_rank(profile.shared_slots)),
            std::cmp::Reverse(goal_fit(my_intention, my_level_for_sport, profile)),
            profile
                .distance_km
                .map(|d| (d * 1000.0) as i64)
                .unwrap_or(i64::MAX),
        )
    });

    // 50 y no 20: la pantalla dejó de ser un mazo de tres tarjetas y pasó a
    // ser una lista que se recorre con el pulgar, así que cortar en 20
    // escondía gente que sí cabía en la respuesta.
    result.truncate(50);

    Ok(result)
}

/// Cuánta gente jugable hay ya alrededor de un punto.
///
/// Existe para una pregunta que hasta ahora la app contestaba demasiado
/// tarde: al elegir sitio en el registro. Alguien rellena seis pantallas,
/// sube una foto, y **entonces** descubre que Descubrir está vacío. Con esto,
/// el paso de ubicación dice "12 personas juegan al tenis a menos de 25 km"
/// mientras aún está eligiendo, y cuando el número es 0 se puede decir la
/// verdad en vez de dejar que la descubra al final.
///
/// **No lleva autenticación**, y no puede llevarla: en el registro no hay
/// cuenta todavía (nada se crea hasta el último paso del wizard). Devuelve un
/// número y nada más — ni perfiles, ni nombres, ni posiciones — y va detrás
/// del mismo limitador por IP que `/auth/login`, así que no sirve para
/// enumerar a nadie.
pub async fn density(
    state: &AppState,
    lat: f64,
    lng: f64,
    radius_km: f64,
    sport: Sport,
) -> Result<i64, DiscoverError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| DiscoverError::Pool(e.to_string()))?;

    let radius_km = radius_km.clamp(1.0, 300.0);

    // Caja envolvente en SQL para no traerse la tabla entera, y la
    // distancia real (Haversine) en Rust sobre lo que quede — mismo reparto
    // que el filtro de distancia del feed. La caja es generosa a propósito:
    // sobra con que no descarte a nadie que sí entra en el círculo.
    let lat_delta = radius_km / 111.0;
    let lng_delta = radius_km / (111.0 * lat.to_radians().cos().abs().max(0.01));

    let rows = profiles::table
        .filter(profiles::sports.contains(vec![sport]))
        // Mismo criterio de "perfil completo" que el feed: si no saldría en
        // Descubrir, contarlo aquí sería prometer gente que no se va a ver.
        .filter(profiles::photos.ne(Vec::<String>::new()))
        .filter(profiles::latitude.is_not_null())
        .filter(profiles::longitude.is_not_null())
        .filter(profiles::latitude.between(lat - lat_delta, lat + lat_delta))
        .filter(profiles::longitude.between(lng - lng_delta, lng + lng_delta))
        .select((profiles::latitude, profiles::longitude))
        .limit(1000)
        .load::<(Option<f64>, Option<f64>)>(&mut conn)
        .await?;

    let count = rows
        .into_iter()
        .filter_map(|(p_lat, p_lng)| p_lat.zip(p_lng))
        .filter(|(p_lat, p_lng)| haversine_km(lat, lng, *p_lat, *p_lng) <= radius_km)
        .count();

    Ok(count as i64)
}

/// Cuánto pesa coincidir en el horario, a efectos de orden.
///
/// **Esto invierte la decisión del 2026-08-23**, que sacó la disponibilidad
/// del orden del feed. Entonces era correcta: el dato era un enum de seis
/// franjas gruesas rellenado en el registro y que no se veía en ninguna
/// pantalla, así que ordenar "a quién conoces" por él era decidir con algo
/// que nadie había mirado nunca. Ahora es lo contrario: es una rejilla de 21
/// huecos, editable desde Ajustes, visible en el perfil, y —lo que cambia el
/// argumento— **es lo que la persona que mira acaba de pedir explícitamente**
/// en el filtro de "cuándo puedes jugar". Coincidir en el horario dejó de ser
/// un dato blando sobre alguien y pasó a ser la pregunta.
///
/// Lo que se conserva de aquella decisión es la desconfianza en la precisión:
/// se agrupa en 0 / 1 / 2 / 3-o-más en vez de ordenar por el número crudo.
/// Con el número crudo, quien marca la semana entera gana siempre — y marcar
/// 21 huecos no es estar más disponible, es haber arrastrado el dedo más
/// rato. A partir de tres coincidencias ya hay margen de sobra para quedar,
/// y lo que decide es el nivel y la distancia.
fn overlap_rank(shared_slots: i32) -> i32 {
    shared_slots.min(3)
}

/// Cuanto encaja un candidato con lo que **tu** has dicho que buscas.
///
/// La parte que importa es la inversion para `Learn`: quien dice que quiere
/// mejorar de nivel esta pidiendo, literalmente, jugar con alguien mejor. Y
/// hasta ahora el feed le ponia primero a los de su mismo nivel, o sea justo
/// lo contrario de lo que habia pedido. Es el unico caso en que "a tu nivel"
/// no es la respuesta correcta.
fn goal_fit(
    my_intention: Option<Intention>,
    my_level: Option<(Sport, SkillLevel)>,
    candidate: &DiscoverProfile,
) -> i32 {
    let same_intention = match (my_intention, candidate.intention) {
        (Some(mine), Some(theirs)) if mine == theirs => 1,
        _ => 0,
    };

    let level_fit = match (my_intention, my_level) {
        (Some(Intention::Learn), Some((sport, mine))) => {
            let better = candidate
                .skill_levels
                .iter()
                .any(|e| e.sport == sport && e.level > mine);
            if better {
                2
            } else {
                0
            }
        }
        _ if candidate.matches_your_level => 2,
        _ => 0,
    };

    level_fit + same_intention
}
