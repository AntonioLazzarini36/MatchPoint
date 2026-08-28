//! Deja un perfil recién creado con la app **ya en marcha**: un par de
//! compañeros, una conversación empezada y dos partidos en la agenda.
//!
//! Existe por un problema de enseñar la app, no de usarla. Una cuenta nueva
//! entra a tres pantallas vacías: Descubrir con perfiles que todavía no le
//! han dado like, Compañeros vacío y Partidos vacío. Para enseñarle a
//! alguien de qué va esto hay que registrar dos cuentas, darse like desde
//! las dos, escribirse y proponer un partido — cinco minutos de trastear
//! delante de la persona a la que le quieres enseñar el producto.
//!
//! **Sólo se activa en desarrollo.** `AppConfig::demo_seed_new_users` sale de
//! `DEMO_SEED_NEW_USERS`, y su valor por defecto es "sí en development, no en
//! production". En producción esto sería mentirle a la gente: compañeros que
//! no eligió y partidos que nadie le propuso.
//!
//! Nada de lo que hace es especial: son los mismos swipes, matches, mensajes
//! y propuestas que crearía la app. Se puede deshacer un match, rechazar la
//! propuesta o borrar la cuenta igual que con cualquier otro.

use chrono::{Duration, Utc};
use diesel::prelude::*;
use diesel::PgArrayExpressionMethods;
use diesel_async::{AsyncPgConnection, RunQueryDsl};

use crate::chats::crypto;
use crate::models::{
    NewMatch, NewMessage, NewProposal, NewSessionFeedback, NewSwipe, ProposalStatus,
    SessionOutcome, Sport, SwipeType,
};
use crate::schema::{matches, messages, profiles, proposals, session_feedback, swipes, users};
use crate::state::AppState;

/// Con cuánta gente se empieza. Tres: suficiente para que las listas no se
/// vean vacías, poco para que siga siendo evidente que la app está recién
/// estrenada.
const COMPANIONS: usize = 3;

/// Lo lanza `me::service::update_profile` la primera vez que aparece un
/// perfil. Nunca falla hacia fuera: si algo va mal se registra y ya está —
/// que la demo no salga no puede impedir que alguien se registre.
pub async fn seed_new_user(state: &AppState, user_id: &str) {
    if !state.config.demo_seed_new_users {
        return;
    }
    if let Err(e) = try_seed(state, user_id).await {
        tracing::warn!("demo: no se pudo sembrar la cuenta {user_id}: {e}");
    }
}

async fn try_seed(state: &AppState, user_id: &str) -> anyhow::Result<()> {
    let mut conn = state.db.get().await.map_err(|e| anyhow::anyhow!("{e}"))?;

    let my_sports = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select(profiles::sports)
        .first::<Vec<Sport>>(&mut conn)
        .await?;
    // `.iter().next()` y no `.first()`: `RunQueryDsl` tiene un impl generico
    // para cualquier `T`, asi que con ese trait importado `Vec::first` se
    // resuelve al `first` de Diesel y el error que sale no se parece en nada
    // a la causa.
    let sport = my_sports.iter().copied().next().unwrap_or(Sport::Tennis);

    // Sólo perfiles sembrados (`@example.com`), nunca cuentas de personas
    // reales: en una base de desarrollo compartida, engancharle a alguien un
    // match con la cuenta de otra persona sin que ninguna de las dos haya
    // hecho nada sería peor que la pantalla vacía.
    let candidates = profiles::table
        .inner_join(users::table.on(users::id.eq(profiles::user_id)))
        .filter(users::email.like("%@example.com"))
        .filter(profiles::user_id.ne(user_id))
        .filter(profiles::sports.contains(vec![sport]))
        .filter(profiles::photos.ne(Vec::<String>::new()))
        .select(profiles::user_id)
        .limit(COMPANIONS as i64)
        .load::<String>(&mut conn)
        .await?;

    if candidates.is_empty() {
        tracing::info!("demo: no hay perfiles sembrados con los que emparejar");
        return Ok(());
    }

    for (i, other) in candidates.iter().enumerate() {
        let match_id = make_match(&mut conn, user_id, other, sport).await?;

        // El primero llega con conversación y con una propuesta esperando
        // respuesta: es el estado que mejor enseña de qué va la app, porque
        // hay algo que **hacer** nada más entrar.
        if i == 0 {
            say(
                state,
                &mut conn,
                &match_id,
                other,
                "¡Hola! ¿Te va bien el sábado por la mañana?",
            )
            .await?;
            propose(
                &mut conn,
                &match_id,
                other,
                sport,
                ProposalStatus::Pending,
                Duration::days(2),
            )
            .await?;
        }

        // El tercero trae **historial**: dos partidos ya jugados, uno ganado
        // y otro perdido. Sin esto la sección "Terminados" sale vacía en una
        // cuenta recién hecha, que es justo la pantalla que peor se enseña —
        // el historial es la prueba de que la app sirve para algo, y sin
        // ninguno hay que creérselo.
        if i == 2 {
            played(
                &mut conn,
                &match_id,
                other,
                user_id,
                sport,
                Duration::days(6),
                SessionOutcome::Won,
            )
            .await?;
            played(
                &mut conn,
                &match_id,
                other,
                user_id,
                sport,
                Duration::days(20),
                SessionOutcome::Lost,
            )
            .await?;
        }

        // El segundo, con un partido ya confirmado, para que la pestaña de
        // Partidos tenga las dos secciones y no sólo una.
        if i == 1 {
            say(
                state,
                &mut conn,
                &match_id,
                other,
                "Nos vemos en la pista 👊",
            )
            .await?;
            propose(
                &mut conn,
                &match_id,
                other,
                sport,
                ProposalStatus::Accepted,
                Duration::days(5),
            )
            .await?;
        }
    }

    tracing::info!(
        "demo: cuenta {user_id} sembrada con {} compañeros",
        candidates.len()
    );
    Ok(())
}

/// Los dos likes y el match, igual que si se hubieran deslizado el uno al
/// otro. Los swipes hacen falta de verdad: sin ellos `/discover` seguiría
/// enseñando a esa persona, que ya es tu compañera.
async fn make_match(
    conn: &mut AsyncPgConnection,
    me: &str,
    other: &str,
    sport: Sport,
) -> anyhow::Result<String> {
    for (from, to) in [(me, other), (other, me)] {
        diesel::insert_into(swipes::table)
            .values(NewSwipe {
                id: uuid::Uuid::new_v4().to_string(),
                from_user_id: from.to_string(),
                to_user_id: to.to_string(),
                sport,
                swipe_type: SwipeType::Like,
            })
            .on_conflict((swipes::from_user_id, swipes::to_user_id, swipes::sport))
            .do_nothing()
            .execute(conn)
            .await?;
    }

    // Mismo criterio que `swipes::service`: el id menor va primero, para que
    // la pareja caiga siempre en la misma fila.
    let (a, b) = if me < other { (me, other) } else { (other, me) };

    let id = diesel::insert_into(matches::table)
        .values(NewMatch {
            id: uuid::Uuid::new_v4().to_string(),
            user_a_id: a.to_string(),
            user_b_id: b.to_string(),
            sport,
        })
        .on_conflict((matches::user_a_id, matches::user_b_id, matches::sport))
        .do_update()
        .set(matches::sport.eq(sport))
        .returning(matches::id)
        .get_result::<String>(conn)
        .await?;

    Ok(id)
}

/// Un mensaje, cifrado con la misma clave que los de verdad — si se guardara
/// en claro, el chat lo leería como basura al intentar descifrarlo.
async fn say(
    state: &AppState,
    conn: &mut AsyncPgConnection,
    match_id: &str,
    sender: &str,
    text: &str,
) -> anyhow::Result<()> {
    let ciphertext = crypto::encrypt_text(text, &state.config.message_key_base64)
        .map_err(|e| anyhow::anyhow!("{e}"))?;

    diesel::insert_into(messages::table)
        .values(NewMessage {
            id: uuid::Uuid::new_v4().to_string(),
            match_id: match_id.to_string(),
            sender_id: sender.to_string(),
            ciphertext,
        })
        .execute(conn)
        .await?;
    Ok(())
}

/// Un partido que ya pasó, con su resultado contado.
///
/// Se inserta con la fecha en el pasado directamente, saltándose la
/// validación de `proposals::service::create` (que con razón no deja proponer
/// para ayer): aquí no se está proponiendo nada, se está reconstruyendo algo
/// que habría ocurrido.
///
/// El resultado se guarda **sólo del lado del usuario nuevo**: es lo único
/// que `/me/proposals/history` devuelve, y rellenar también la fila de la
/// otra persona sería inventarle una opinión a un perfil sembrado.
#[allow(clippy::too_many_arguments)]
async fn played(
    conn: &mut AsyncPgConnection,
    match_id: &str,
    proposed_by: &str,
    user_id: &str,
    sport: Sport,
    ago: Duration,
    outcome: SessionOutcome,
) -> anyhow::Result<()> {
    let when = (Utc::now() - ago)
        .date_naive()
        .and_hms_opt(18, 0, 0)
        .map(|d| d.and_utc())
        .unwrap_or_else(|| Utc::now() - ago);

    let proposal_id = uuid::Uuid::new_v4().to_string();
    diesel::insert_into(proposals::table)
        .values(NewProposal {
            id: proposal_id.clone(),
            match_id: match_id.to_string(),
            proposed_by_id: proposed_by.to_string(),
            sport,
            place_name: Some("Club de Tenis Capellanía".to_string()),
            place_lat: Some(36.5987),
            place_lng: Some(-4.5432),
            scheduled_at: when,
            status: ProposalStatus::Accepted,
            updated_at: Utc::now(),
        })
        .execute(conn)
        .await?;

    diesel::insert_into(session_feedback::table)
        .values(NewSessionFeedback {
            id: uuid::Uuid::new_v4().to_string(),
            proposal_id,
            user_id: user_id.to_string(),
            played: true,
            outcome: Some(outcome),
            would_repeat: Some(true),
        })
        .execute(conn)
        .await?;

    Ok(())
}

async fn propose(
    conn: &mut AsyncPgConnection,
    match_id: &str,
    proposed_by: &str,
    sport: Sport,
    status: ProposalStatus,
    ahead: Duration,
) -> anyhow::Result<()> {
    // A las 10:00 del día que toque, no "dentro de 48 horas exactas": una
    // propuesta a las 3 de la madrugada delata al instante que la ha puesto
    // una máquina.
    let when = (Utc::now() + ahead)
        .date_naive()
        .and_hms_opt(10, 0, 0)
        .unwrap_or_else(|| (Utc::now() + ahead).naive_utc())
        .and_utc();

    diesel::insert_into(proposals::table)
        .values(NewProposal {
            id: uuid::Uuid::new_v4().to_string(),
            match_id: match_id.to_string(),
            proposed_by_id: proposed_by.to_string(),
            sport,
            place_name: Some("Club de Tenis Capellanía".to_string()),
            place_lat: Some(36.5987),
            place_lng: Some(-4.5432),
            scheduled_at: when,
            status,
            updated_at: Utc::now(),
        })
        .execute(conn)
        .await?;
    Ok(())
}
