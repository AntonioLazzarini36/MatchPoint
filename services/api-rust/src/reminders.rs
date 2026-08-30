//! Los avisos que hay que mandar **antes** de que pase algo, no después.
//!
//! Todo lo demás que notifica esta app reacciona a una acción de otra persona:
//! te escriben, te proponen, te aceptan. Eso ya funcionaba. Lo que no existía
//! es lo único que depende del reloj y no de nadie:
//!
//! 1. **Mañana juegas.** En una app cuyo único éxito es que dos personas
//!    aparezcan en una pista, éste es el aviso que más importa — y el que no
//!    puede mandar nadie, porque no hay ninguna acción que lo dispare.
//! 2. **Cuenta qué tal fue.** Existía el contador en la barra, pero sólo lo ve
//!    quien abre la app. El bucle del producto —y con él la única métrica que
//!    vale, partidos jugados— dependía de que a alguien se le ocurriera entrar.
//!
//! Un bucle en el proceso y no un cron externo: Railway no da cron en el plan
//! que usamos, y montar un servicio aparte para dos consultas por hora sería
//! más infraestructura que problema.
//!
//! **Gotcha — esto asume una sola instancia.** Con dos procesos, los dos
//! mandarían el mismo aviso. Hoy corre una, igual que el limitador de peticiones
//! (ver `auth::rate_limit`), y la solución el día que haya varias es la misma
//! para ambos: sacar el estado a la base o a Redis.

use chrono::{DateTime, Duration, Utc};
use diesel::prelude::*;
use diesel_async::RunQueryDsl;

use crate::models::{ProposalStatus, Sport};
use crate::schema::{matches, profiles, proposals, session_feedback};
use crate::state::AppState;

/// Cada cuánto se mira si hay algo que avisar.
///
/// Una hora es suficiente para los dos casos y deja la carga en nada: son dos
/// consultas indexadas por fecha. Afinar más obligaría a guardar por minuto
/// qué se ha mandado ya.
const TICK: std::time::Duration = std::time::Duration::from_secs(3600);

/// Con cuánta antelación se avisa de un partido.
///
/// Un día: lo justo para poder cancelar sin dejar tirado a nadie, y lo bastante
/// cerca como para que no se te olvide otra vez. Avisar una semana antes no
/// sirve para nada y avisar una hora antes llega tarde para reorganizarse.
const REMIND_BEFORE_HOURS: i64 = 24;

/// Cuánto se espera tras un partido para preguntar qué tal fue.
///
/// Tres horas: acabado y con tiempo de llegar a casa, pero el mismo día — al
/// día siguiente ya nadie se acuerda de los detalles, que es justo el problema
/// que este aviso resuelve.
const ASK_AFTER_HOURS: i64 = 3;

/// Arranca el bucle. No devuelve nunca; se lanza con `tokio::spawn`.
pub fn spawn(state: AppState) {
    tokio::spawn(async move {
        // Un respiro al arrancar: durante el despliegue la base puede estar
        // todavía aplicando migraciones, y un fallo aquí no debe ensuciar el
        // arranque con un error que se arregla solo.
        tokio::time::sleep(std::time::Duration::from_secs(30)).await;

        loop {
            if let Err(e) = tick(&state).await {
                // Se registra y se sigue: que falle una vuelta no puede matar
                // el bucle, o se dejarían de mandar avisos para siempre y sin
                // que nadie se entere.
                tracing::warn!("recordatorios: fallo en esta vuelta: {e}");
            }
            tokio::time::sleep(TICK).await;
        }
    });
}

async fn tick(state: &AppState) -> anyhow::Result<()> {
    let sent = remind_upcoming(state).await?;
    let asked = ask_for_feedback(state).await?;
    if sent > 0 || asked > 0 {
        // `sent` cuenta partidos y `asked` personas: cada partido avisa a los
        // dos, pero lo de "cuéntanos" sólo a quien no lo haya contado ya.
        tracing::info!("recordatorios: {sent} partidos mañana, {asked} por preguntar");
    }
    Ok(())
}

/// "Mañana juegas con X".
///
/// Se manda a **las dos personas**: las dos tienen que aparecer.
///
/// La ventana es de una hora, la misma del tick, y ése es el truco que evita
/// tener que guardar en la base a quién se le ha avisado ya: en cada vuelta se
/// cogen sólo los partidos que entran en las próximas 24-25 h, así que cada uno
/// cae en exactamente una vuelta. Si el proceso se reinicia justo en esa hora se
/// pierde el aviso de ese partido, y es un precio aceptable frente a añadir una
/// columna y su migración.
async fn remind_upcoming(state: &AppState) -> anyhow::Result<usize> {
    let mut conn = state.db.get().await.map_err(|e| anyhow::anyhow!("{e}"))?;

    let from = Utc::now() + Duration::hours(REMIND_BEFORE_HOURS);
    let to = from + Duration::from_std(TICK)?;

    let rows = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(proposals::status.eq(ProposalStatus::Accepted))
        .filter(proposals::scheduled_at.ge(from))
        .filter(proposals::scheduled_at.lt(to))
        .select((
            proposals::id,
            proposals::match_id,
            proposals::scheduled_at,
            proposals::sport,
            proposals::place_name,
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(
            String,
            String,
            DateTime<Utc>,
            Sport,
            Option<String>,
            String,
            String,
        )>(&mut conn)
        .await?;

    let count = rows.len();
    for (proposal_id, match_id, when, sport, place, user_a, user_b) in rows {
        for (me, other) in [(&user_a, &user_b), (&user_b, &user_a)] {
            let name = display_name(&mut conn, other).await;
            let cuerpo = match &place {
                Some(p) => format!("{} · {p}", hora(when)),
                None => hora(when),
            };
            crate::push::spawn_notify(
                state,
                me,
                format!("Mañana juegas con {name}"),
                cuerpo,
                serde_json::json!({
                    "type": "reminder",
                    "matchId": match_id,
                    "proposalId": proposal_id,
                    "sport": sport,
                }),
            );
        }
    }

    Ok(count)
}

/// "¿Qué tal fue?" — sólo a quien todavía no lo ha contado.
///
/// Misma ventana de una hora y por el mismo motivo. Se pregunta por separado a
/// cada parte: que una haya contestado no dice nada de la otra.
async fn ask_for_feedback(state: &AppState) -> anyhow::Result<usize> {
    let mut conn = state.db.get().await.map_err(|e| anyhow::anyhow!("{e}"))?;

    let to = Utc::now() - Duration::hours(ASK_AFTER_HOURS);
    let from = to - Duration::from_std(TICK)?;

    let rows = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(proposals::status.eq(ProposalStatus::Accepted))
        .filter(proposals::scheduled_at.ge(from))
        .filter(proposals::scheduled_at.lt(to))
        .select((
            proposals::id,
            proposals::match_id,
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(String, String, String, String)>(&mut conn)
        .await?;

    let mut asked = 0;
    for (proposal_id, match_id, user_a, user_b) in rows {
        for (me, other) in [(&user_a, &user_b), (&user_b, &user_a)] {
            let already = session_feedback::table
                .filter(session_feedback::proposal_id.eq(&proposal_id))
                .filter(session_feedback::user_id.eq(me))
                .select(session_feedback::id)
                .first::<String>(&mut conn)
                .await
                .optional()?;
            if already.is_some() {
                continue;
            }

            let name = display_name(&mut conn, other).await;
            crate::push::spawn_notify(
                state,
                me,
                "¿Qué tal fue el partido?".to_string(),
                format!("Cuéntanos si jugasteis {name} y tú"),
                serde_json::json!({
                    "type": "feedback",
                    "matchId": match_id,
                    "proposalId": proposal_id,
                }),
            );
            asked += 1;
        }
    }

    Ok(asked)
}

async fn display_name(conn: &mut diesel_async::AsyncPgConnection, user_id: &str) -> String {
    profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select(profiles::display_name)
        .first::<String>(conn)
        .await
        .optional()
        .ok()
        .flatten()
        .unwrap_or_else(|| "tu compañero".to_string())
}

/// "a las 18:30". El día no se dice porque el título ya pone "mañana".
fn hora(when: DateTime<Utc>) -> String {
    format!("A las {}", when.format("%H:%M"))
}
