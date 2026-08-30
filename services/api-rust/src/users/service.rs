//! Direct port of users.service.ts.
//!
//! Reuses `DiscoverProfile` from the discover module — users.service.ts
//! itself comments that its return shape is "similar to DiscoverProfile"
//! on purpose, so instead of duplicating the struct we just import it.

use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;

use serde::Serialize;
use utoipa::ToSchema;

use crate::discover::service::{age_from_birth_date, fetch_skill_levels, DiscoverProfile};
use crate::models::{NewReport, SkillLevel};
use crate::schema::{profiles, reports, skill_levels};
use crate::state::AppState;

#[derive(thiserror::Error, Debug)]
pub enum UsersError {
    #[error("Esa persona ya no está disponible")]
    UserNotFound,
    #[error("No encontramos ese perfil")]
    ProfileNotFound,
    #[error("No puedes reportarte a ti mismo")]
    CannotTargetSelf,
    #[error("El motivo debe tener entre 1 y 1000 caracteres")]
    InvalidReason,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

pub async fn get_profile(state: &AppState, user_id: &str) -> Result<DiscoverProfile, UsersError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| UsersError::Pool(e.to_string()))?;

    let row = profiles::table
        .filter(profiles::user_id.eq(user_id))
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
            profiles::years_playing,
            profiles::club,
            profiles::achievements,
            profiles::avg_pace_min_per_km,
            profiles::avg_distance_km,
        ))
        .first::<(
            String,
            String,
            chrono::DateTime<chrono::Utc>,
            Option<crate::models::Gender>,
            Option<crate::models::Intention>,
            Option<String>,
            Option<String>,
            Vec<String>,
            Vec<crate::models::Sport>,
            i32,
            Option<i32>,
            Option<String>,
            Vec<String>,
            Option<f64>,
            Option<f64>,
        )>(&mut conn)
        .await
        .optional()?
        .ok_or(UsersError::ProfileNotFound)?;

    let (
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
        years_playing,
        club,
        achievements,
        avg_pace_min_per_km,
        avg_distance_km,
    ) = row;
    let skill_levels = fetch_skill_levels(&mut conn, &user_id).await?;
    let record = player_record(&mut conn, &user_id).await?;

    Ok(DiscoverProfile {
        // Todos estos son relativos a quien mira, no propiedades publicas
        // del perfil, y este endpoint no sabe quien mira mas alla de que
        // este autenticado — ver los campos en discover/service.rs.
        distance_km: None,
        matches_your_level: false,
        likes_you: false,
        shared_availability: 0,
        shared_slots: 0,
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
        skill_levels,
        // Éste es el único endpoint que los rellena — ver el comentario del
        // campo en `discover/service.rs`.
        played_count: Some(record.played),
        won_count: Some(record.won),
        level_verdict: record.level_verdict,
        level_votes: record.level_votes,
    })
}

/// Qué opina de tu nivel la gente que ha jugado contigo.
///
/// Tres respuestas y no más: o el nivel que dices está bien, o te quedas
/// corto, o te sobra. Deliberadamente grueso — con cuatro niveles y partidos
/// contados con los dedos, cualquier cosa más fina sería precisión inventada.
#[derive(Debug, Serialize, ToSchema, PartialEq, Eq, Clone, Copy)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum LevelVerdict {
    /// La mayoría cree que juegas al nivel que dices.
    Accurate,
    /// La mayoría te pone por encima de lo que declaras.
    Higher,
    /// La mayoría te pone por debajo.
    Lower,
}

/// Cuántos partidos ha jugado alguien, cuántos dice haber ganado, y qué
/// opinan los demás de su nivel.
pub struct PlayerRecord {
    pub played: i64,
    pub won: i64,
    /// `None` si nadie ha valorado su nivel todavía. La app no enseña la
    /// fila entera en ese caso, en vez de decir "0 valoraciones", que suena
    /// a que alguien lo miró y no opinó.
    pub level_verdict: Option<LevelVerdict>,
    pub level_votes: i64,
}

/// Cuenta los votos y se queda con el que más tenga.
///
/// **Los empates los gana `Accurate`**, siempre. No es indecisión: en la
/// duda, lo que la persona dice de sí misma es lo que vale — corregir a
/// alguien hace falta que esté claro, y "tres dicen que sí y tres que no" no
/// lo está. Vale igual para el empate entre `Higher` y `Lower`, donde además
/// las dos mitades se están contradiciendo entre ellas.
fn winning_verdict(accurate: i64, higher: i64, lower: i64) -> Option<LevelVerdict> {
    if accurate + higher + lower == 0 {
        return None;
    }
    if higher > accurate && higher > lower {
        return Some(LevelVerdict::Higher);
    }
    if lower > accurate && lower > higher {
        return Some(LevelVerdict::Lower);
    }
    Some(LevelVerdict::Accurate)
}

/// Se calcula en Rust y no en SQL a propósito: son dos filas por partido como
/// mucho (`SessionFeedback` tiene una por persona y propuesta), así que traerlas
/// y contarlas cuesta nada, y las reglas de abajo son bastante más legibles
/// aquí que dentro de una consulta.
///
/// **Las dos cifras se cuentan distinto porque no valen lo mismo:**
///
/// - `played` cuenta un partido si **cualquiera de los dos** confirmó que se
///   jugó. Es la misma regla que `playedTogether` en `/matches`, y la razón es
///   que hace falta otra persona para inflarla: nadie puede fabricarse
///   partidos solo.
/// - `won` sale de lo que declara cada uno, que sí es inflable. El único
///   filtro posible sin árbitro es el desacuerdo evidente: si el rival
///   también dice haber ganado ese mismo partido, no cuenta para ninguno. No
///   convierte el número en verdad, pero quita el caso descarado — y evita
///   que la app dé por buena una contradicción que ella misma tiene delante.
pub async fn player_record(
    conn: &mut diesel_async::AsyncPgConnection,
    user_id: &str,
) -> Result<PlayerRecord, UsersError> {
    use crate::models::SessionOutcome;
    use crate::schema::{matches, proposals, session_feedback};

    // Los partidos de esta persona: las propuestas de sus matches.
    let proposal_ids = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .select(proposals::id)
        .load::<String>(conn)
        .await?;

    if proposal_ids.is_empty() {
        return Ok(PlayerRecord {
            played: 0,
            won: 0,
            level_verdict: None,
            level_votes: 0,
        });
    }

    let rows = session_feedback::table
        .filter(session_feedback::proposal_id.eq_any(&proposal_ids))
        .select((
            session_feedback::proposal_id,
            session_feedback::user_id,
            session_feedback::played,
            session_feedback::outcome,
            session_feedback::assessed_level,
        ))
        .load::<(
            String,
            String,
            bool,
            Option<SessionOutcome>,
            Option<SkillLevel>,
        )>(conn)
        .await?;

    // El nivel que declara **hoy** en tenis, que es contra lo que se comparan
    // las valoraciones. Se resuelve el veredicto aquí y no al guardar por eso
    // mismo: si mañana cambia su nivel, las opiniones viejas se recolocan
    // solas en vez de quedarse juzgando algo que ya no dice.
    let declared = skill_levels::table
        .filter(skill_levels::user_id.eq(user_id))
        .filter(skill_levels::sport.eq(crate::models::Sport::Tennis))
        .select(skill_levels::level)
        .first::<SkillLevel>(conn)
        .await
        .optional()?;

    let (mut accurate, mut higher, mut lower) = (0i64, 0i64, 0i64);
    for (_, reviewer, _, _, assessed) in &rows {
        // Sólo lo que opinan **los demás**: lo que uno diga de su propio
        // nivel ya está en el nivel que declara, contarlo otra vez sería
        // dejarle votarse a sí mismo.
        if reviewer == user_id {
            continue;
        }
        let (Some(assessed), Some(declared)) = (assessed, declared) else {
            continue;
        };
        match assessed.cmp(&declared) {
            std::cmp::Ordering::Equal => accurate += 1,
            std::cmp::Ordering::Greater => higher += 1,
            std::cmp::Ordering::Less => lower += 1,
        }
    }

    let mut played = 0i64;
    let mut won = 0i64;

    for proposal_id in &proposal_ids {
        let for_this: Vec<_> = rows.iter().filter(|r| &r.0 == proposal_id).collect();
        if for_this.is_empty() {
            continue;
        }

        // Basta con que uno lo diga.
        if for_this.iter().any(|r| r.2) {
            played += 1;
        }

        let mine_won = for_this
            .iter()
            .any(|r| r.1 == user_id && r.3 == Some(SessionOutcome::Won));
        let theirs_won = for_this
            .iter()
            .any(|r| r.1 != user_id && r.3 == Some(SessionOutcome::Won));
        if mine_won && !theirs_won {
            won += 1;
        }
    }

    Ok(PlayerRecord {
        played,
        won,
        level_verdict: winning_verdict(accurate, higher, lower),
        level_votes: accurate + higher + lower,
    })
}

/// A propósito NO borra el match — reportar es solo dejar constancia para
/// revisión. Si además quieres cortar todo contacto, eso es un unmatch
/// aparte (`DELETE /matches/:matchId`), acción explícita del usuario.
pub async fn report_user(
    state: &AppState,
    reporter_id: &str,
    reported_id: &str,
    reason: &str,
) -> Result<(), UsersError> {
    if reporter_id == reported_id {
        return Err(UsersError::CannotTargetSelf);
    }
    if reason.trim().is_empty() || reason.chars().count() > 1000 {
        return Err(UsersError::InvalidReason);
    }

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| UsersError::Pool(e.to_string()))?;

    // Igual que en swipes: sin esto, denunciar a alguien que acaba de borrar
    // su cuenta salia como 500 por violacion de clave foranea.
    let exists = diesel::select(diesel::dsl::exists(
        crate::schema::users::table.filter(crate::schema::users::id.eq(reported_id)),
    ))
    .get_result::<bool>(&mut conn)
    .await?;
    if !exists {
        return Err(UsersError::UserNotFound);
    }

    diesel::insert_into(reports::table)
        .values(NewReport {
            id: uuid::Uuid::new_v4().to_string(),
            reporter_user_id: reporter_id.to_string(),
            reported_user_id: reported_id.to_string(),
            reason: reason.to_string(),
        })
        .execute(&mut conn)
        .await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sin_valoraciones_no_hay_veredicto() {
        // Y no "Accurate por defecto": nadie ha dicho que tu nivel esté bien,
        // simplemente no ha jugado nadie contigo todavía.
        assert_eq!(winning_verdict(0, 0, 0), None);
    }

    #[test]
    fn gana_la_mayoria() {
        assert_eq!(winning_verdict(5, 1, 1), Some(LevelVerdict::Accurate));
        assert_eq!(winning_verdict(1, 5, 1), Some(LevelVerdict::Higher));
        assert_eq!(winning_verdict(1, 1, 5), Some(LevelVerdict::Lower));
    }

    /// La regla que hay que respetar al tocar esto: **el empate lo gana
    /// siempre "correcto"**. Corregir a alguien tiene que estar claro, y un
    /// empate no lo está.
    #[test]
    fn los_empates_los_gana_el_nivel_declarado() {
        // Empate a tres bandas.
        assert_eq!(winning_verdict(2, 2, 2), Some(LevelVerdict::Accurate));
        // Empate entre "correcto" y "más alto".
        assert_eq!(winning_verdict(4, 4, 0), Some(LevelVerdict::Accurate));
        // Empate entre "más alto" y "más bajo", que además se contradicen
        // entre ellos: con más razón manda lo que dice la persona.
        assert_eq!(winning_verdict(0, 3, 3), Some(LevelVerdict::Accurate));
        // El caso de 8 valoraciones del ejemplo: 3/3/2 gana "correcto".
        assert_eq!(winning_verdict(3, 3, 2), Some(LevelVerdict::Accurate));
    }

    #[test]
    fn una_sola_voz_discrepante_basta_si_esta_sola() {
        assert_eq!(winning_verdict(0, 1, 0), Some(LevelVerdict::Higher));
    }
}
