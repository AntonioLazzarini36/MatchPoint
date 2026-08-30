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
use crate::schema::{
    matches, messages, preferences, profiles, proposals, session_feedback, swipes, users,
};
use crate::state::AppState;

/// Cuántos perfiles pasan a ser compañeros (match hecho).
const COMPANIONS: usize = 3;

/// Cuántos, además, llegan con un "quiero jugar" ya dado — sin match todavía.
///
/// Son los que salen destacados en Descubrir con "Ya quiere jugar contigo", y
/// hacen falta para poder enseñar esa pantalla: sin ellos, Descubrir es una
/// lista de desconocidos y no se ve la parte que engancha, que es entrar y
/// encontrarte con que alguien ya te ha elegido. Un toque tuyo y hay match,
/// que es la demostración entera en un gesto.
const INBOUND_LIKES: usize = 2;

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

    let (my_sports, my_lat, my_lng) = profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select((profiles::sports, profiles::latitude, profiles::longitude))
        .first::<(Vec<Sport>, Option<f64>, Option<f64>)>(&mut conn)
        .await?;
    let my_location = my_lat.zip(my_lng);
    // `.iter().next()` y no `.first()`: `RunQueryDsl` tiene un impl generico
    // para cualquier `T`, asi que con ese trait importado `Vec::first` se
    // resuelve al `first` de Diesel y el error que sale no se parece en nada
    // a la causa.
    let sport = my_sports.iter().copied().next().unwrap_or(Sport::Tennis);

    // Sólo perfiles sembrados (`@example.com`), nunca cuentas de personas
    // reales: en una base de desarrollo compartida, engancharle a alguien un
    // match con la cuenta de otra persona sin que ninguna de las dos haya
    // hecho nada sería peor que la pantalla vacía.
    // **Ordenado por email**, y eso importa más de lo que parece: sin un
    // `ORDER BY` explícito Postgres puede devolver las filas en cualquier
    // orden, así que dos cuentas nuevas seguidas salían con compañeros
    // distintos y con la conversación pegada a otra persona. Para enseñar la
    // app a un club hace falta que la demostración sea **siempre la misma**:
    // el mismo Diego escribiéndote, el mismo partido pendiente, el mismo
    // resultado en el historial.
    let rows = profiles::table
        .inner_join(users::table.on(users::id.eq(profiles::user_id)))
        .filter(users::email.like("%@example.com"))
        .filter(profiles::user_id.ne(user_id))
        .filter(profiles::sports.contains(vec![sport]))
        .filter(profiles::photos.ne(Vec::<String>::new()))
        .order(users::email.asc())
        .select((profiles::user_id, profiles::latitude, profiles::longitude))
        .load::<(String, Option<f64>, Option<f64>)>(&mut conn)
        .await?;

    // **Sólo los que esta persona va a poder ver.**
    //
    // Un like de alguien que cae fuera del radio existe en la base pero no
    // aparece en ningún sitio: `/discover` lo filtra por distancia antes de
    // llegar a marcar `likesYou`. Pasó de verdad — Elena, sembrada en
    // Fuengirola, quedaba a 27 km de un perfil de Málaga con el radio por
    // defecto de 25, así que su "quiero jugar" no se veía y la demostración
    // salía coja sin que nada lo delatara.
    //
    // Se recorta aquí con la misma cuenta que hace el feed, y **antes** de
    // repartir papeles, para que los compañeros y los admiradores salgan
    // siempre de gente visible.
    let radius_km = preferences::table
        .filter(preferences::user_id.eq(user_id))
        .select(preferences::distance_km)
        .first::<i32>(&mut conn)
        .await
        .optional()?
        .unwrap_or(25) as f64;

    let candidates: Vec<String> = match my_location {
        Some((my_lat, my_lng)) => rows
            .into_iter()
            .filter(|(_, lat, lng)| match lat.zip(*lng) {
                Some((lat, lng)) => haversine_km(my_lat, my_lng, lat, lng) <= radius_km,
                // Sin coordenadas no sale en el feed, así que tampoco aquí.
                None => false,
            })
            .map(|(id, _, _)| id)
            .collect(),
        // Sin ubicación propia el feed no filtra por distancia: valen todos.
        None => rows.into_iter().map(|(id, _, _)| id).collect(),
    };
    let candidates: Vec<String> = candidates
        .into_iter()
        .take(COMPANIONS + INBOUND_LIKES)
        .collect();

    if candidates.is_empty() {
        tracing::info!("demo: no hay perfiles sembrados cerca con los que emparejar");
        return Ok(());
    }

    // Los últimos de la lista sólo dan like: quedan sin match, así que siguen
    // apareciendo en Descubrir — que es donde tienen que verse.
    let companions = candidates.iter().take(COMPANIONS);
    let admirers = candidates.iter().skip(COMPANIONS);

    for other in admirers {
        like(&mut conn, other, user_id, sport).await?;
    }

    for (i, other) in companions.enumerate() {
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
            say(
                state,
                &mut conn,
                &match_id,
                other,
                "Buen partido el otro día. ¿Repetimos?",
            )
            .await?;
            played(
                &mut conn,
                &match_id,
                other,
                user_id,
                sport,
                Duration::days(6),
                Some(SessionOutcome::Won),
            )
            .await?;
            played(
                &mut conn,
                &match_id,
                other,
                user_id,
                sport,
                Duration::days(20),
                Some(SessionOutcome::Lost),
            )
            .await?;
            // Y uno **sin contar**, de anteayer: es lo que hace que al abrir
            // la app recién registrada aparezca "¿qué tal fue?" con un partido
            // esperando respuesta. Sin esto, esa pantalla —la que sostiene que
            // los niveles del resto signifiquen algo— sólo se puede enseñar
            // esperando a que alguien juegue de verdad.
            played(
                &mut conn,
                &match_id,
                other,
                user_id,
                sport,
                Duration::days(2),
                None,
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
        "demo: cuenta {user_id} sembrada con {} compañeros y {} likes recibidos",
        candidates.len().min(COMPANIONS),
        candidates.len().saturating_sub(COMPANIONS),
    );
    Ok(())
}

/// La misma cuenta que usa `/discover` para filtrar por distancia. Se repite
/// aquí en vez de exportarla porque son seis líneas y sacarla a un módulo
/// común sólo para esto ataría el sembrado de demo al feed.
fn haversine_km(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    const EARTH_RADIUS_KM: f64 = 6371.0;
    let d_lat = (lat2 - lat1).to_radians();
    let d_lng = (lng2 - lng1).to_radians();
    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (d_lng / 2.0).sin().powi(2);
    EARTH_RADIUS_KM * 2.0 * a.sqrt().asin()
}

/// Un "quiero jugar" de otra persona hacia ti, y nada más.
///
/// Sin el de vuelta no hay match, así que esa persona sigue saliendo en
/// Descubrir — destacada, porque `/discover` marca `likesYou`. Es
/// exactamente el mismo LIKE que crearía la app.
async fn like(
    conn: &mut AsyncPgConnection,
    from: &str,
    to: &str,
    sport: Sport,
) -> anyhow::Result<()> {
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
///
/// Con `outcome: None` el partido queda **sin contar**: pasó, está aceptado, y
/// sale en "¿qué tal fue?" esperando respuesta. Es la única forma de que quien
/// abre la app recién registrada vea funcionar esa parte — es la pantalla que
/// sostiene todo lo demás (el nivel de la gente sólo significa algo porque
/// alguien lo corrige después de jugar) y sin un partido pendiente no hay
/// manera de enseñarla.
#[allow(clippy::too_many_arguments)]
async fn played(
    conn: &mut AsyncPgConnection,
    match_id: &str,
    proposed_by: &str,
    user_id: &str,
    sport: Sport,
    ago: Duration,
    outcome: Option<SessionOutcome>,
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

    // Sin resultado no se escribe fila: la ausencia de `SessionFeedback` es
    // justo lo que hace que la quedada aparezca en "¿qué tal fue?".
    if let Some(outcome) = outcome {
        diesel::insert_into(session_feedback::table)
            .values(NewSessionFeedback {
                id: uuid::Uuid::new_v4().to_string(),
                proposal_id,
                user_id: user_id.to_string(),
                played: true,
                outcome: Some(outcome),
                would_repeat: Some(true),
                // El nivel de un perfil sembrado no lo valora nadie: sería
                // inventarle una opinión a alguien que no existe, y encima
                // acabaría contando en el veredicto público de esa persona.
                assessed_level: None,
                skipped: false,
            })
            .execute(conn)
            .await?;
    }

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
