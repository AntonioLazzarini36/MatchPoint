//! Direct port of users.service.ts.
//!
//! Reuses `DiscoverProfile` from the discover module — users.service.ts
//! itself comments that its return shape is "similar to DiscoverProfile"
//! on purpose, so instead of duplicating the struct we just import it.

use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;

use crate::discover::service::{age_from_birth_date, fetch_skill_levels, DiscoverProfile};
use crate::models::NewReport;
use crate::schema::{profiles, reports};
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
    })
}

/// Cuántos partidos ha jugado alguien y cuántos dice haber ganado.
pub struct PlayerRecord {
    pub played: i64,
    pub won: i64,
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
        return Ok(PlayerRecord { played: 0, won: 0 });
    }

    let rows = session_feedback::table
        .filter(session_feedback::proposal_id.eq_any(&proposal_ids))
        .select((
            session_feedback::proposal_id,
            session_feedback::user_id,
            session_feedback::played,
            session_feedback::outcome,
        ))
        .load::<(String, String, bool, Option<SessionOutcome>)>(conn)
        .await?;

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

    Ok(PlayerRecord { played, won })
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
