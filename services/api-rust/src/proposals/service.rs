//! Business logic for proposals — the "let's actually play" half of a
//! match.
//!
//! Design notes worth knowing before changing anything here:
//! - **El deporte lo deciden las personas, no el match.** `Match.sport`
//!   solo dice por que feed os cruzasteis; si los dos practicais otro
//!   deporte ademas, se puede proponer en la misma conversacion (ver
//!   `assert_both_play`).
//! - **One live proposal per match.** Creating a new one supersedes any
//!   still-pending proposal in that match (`Cancelled`). Two competing
//!   pending offers would leave both sides asking "which one am I
//!   accepting?", and a counter-offer is exactly "no to yours, yes to
//!   mine" anyway.
//! - **Who may do what is asymmetric.** Only the person who did *not*
//!   propose can accept/decline; only the proposer can cancel. Anything
//!   else lets someone accept their own invitation.
//! - **Accept/decline only apply while `Pending`.** Re-accepting or
//!   un-declining is deliberately not a thing: propose again instead, so
//!   the history stays honest. `Cancel` is the exception — it also works
//!   on an `Accepted` session, because plans change, and forcing someone
//!   to just not turn up would be worse than letting either side call it
//!   off explicitly.

use chrono::{DateTime, Duration, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::AsyncPgConnection;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::models::{
    Match, NewProposal, NewSessionFeedback, Proposal, ProposalStatus, SessionFeedback,
    SessionOutcome, Sport,
};
use crate::proposals::dto::{CreateProposalDto, ProposalAction, SessionFeedbackDto};
use crate::schema::{matches, profiles, proposals, session_feedback};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum ProposalsError {
    #[error("No encontramos ese match")]
    MatchNotFound,
    #[error("No encontramos esa quedada")]
    NotFound,
    #[error("No tienes acceso a esto")]
    Forbidden,
    #[error("{0}")]
    InvalidInput(String),
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

fn bad(msg: &str) -> ProposalsError {
    ProposalsError::InvalidInput(msg.to_string())
}

#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ProposalResponse {
    pub id: String,
    pub match_id: String,
    pub proposed_by_id: String,
    /// True when the authenticated caller is the one who proposed it —
    /// saves every client re-deriving it to decide between showing
    /// "Aceptar/Rechazar" and "Cancelar".
    pub mine: bool,
    pub sport: Sport,
    pub place_name: Option<String>,
    pub place_lat: Option<f64>,
    pub place_lng: Option<f64>,
    pub scheduled_at: DateTime<Utc>,
    pub status: ProposalStatus,
    pub created_at: DateTime<Utc>,
}

impl ProposalResponse {
    fn from_row(p: Proposal, viewer_id: &str) -> Self {
        ProposalResponse {
            mine: p.proposed_by_id == viewer_id,
            id: p.id,
            match_id: p.match_id,
            proposed_by_id: p.proposed_by_id,
            sport: p.sport,
            place_name: p.place_name,
            place_lat: p.place_lat,
            place_lng: p.place_lng,
            scheduled_at: p.scheduled_at,
            status: p.status,
            created_at: p.created_at,
        }
    }
}

/// A still-in-the-future session (agreed *or* still on the table) plus
/// just enough about the other person to render a row without a second
/// round-trip.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpcomingSession {
    #[serde(flatten)]
    pub proposal: ProposalResponse,
    pub other_user_id: String,
    pub other_display_name: String,
    pub other_photo: Option<String>,
}

/// Same role as `chats::service::assert_member` — membership in the match
/// is the only authorisation concept these endpoints have.
async fn assert_member(
    conn: &mut AsyncPgConnection,
    match_id: &str,
    user_id: &str,
) -> Result<Match, ProposalsError> {
    let found = matches::table
        .filter(matches::id.eq(match_id))
        .first::<Match>(conn)
        .await
        .optional()?
        .ok_or(ProposalsError::MatchNotFound)?;

    if found.user_a_id != user_id && found.user_b_id != user_id {
        return Err(ProposalsError::Forbidden);
    }

    Ok(found)
}

/// El deporte propuesto tiene que jugarlo **la gente**, no el match.
///
/// Antes se exigia que coincidiera con `Match.sport`. Pero el deporte del
/// match solo dice por que feed os cruzasteis: si los dos jugais al tenis
/// y ademas corres, no hay ninguna razon para no poder proponer una
/// carrera en esa misma conversacion. Obligaba a hacer un segundo match
/// con la misma persona para el otro deporte, cosa que ni el usuario sabe
/// que existe ni tendria por que.
///
/// Lo que si hace falta comprobar es que ambos lo practiquen: proponerle
/// tenis a quien solo corre es una quedada que no va a existir.
async fn assert_both_play(
    conn: &mut AsyncPgConnection,
    found: &Match,
    sport: Sport,
) -> Result<(), ProposalsError> {
    let rows = profiles::table
        .filter(
            profiles::user_id
                .eq(&found.user_a_id)
                .or(profiles::user_id.eq(&found.user_b_id)),
        )
        .select((profiles::user_id, profiles::sports))
        .load::<(String, Vec<Sport>)>(conn)
        .await?;

    // Sin perfil no se puede afirmar que no lo juegue; se deja pasar en vez
    // de bloquear por un dato que falta (mismo criterio que el filtro de
    // genero en discover).
    let both_play = [&found.user_a_id, &found.user_b_id].iter().all(|id| {
        rows.iter()
            .find(|(user_id, _)| user_id == *id)
            .map(|(_, sports)| sports.contains(&sport))
            .unwrap_or(true)
    });

    if !both_play {
        return Err(bad("Uno de los dos no juega a ese deporte"));
    }

    Ok(())
}

fn validate(dto: &CreateProposalDto, when: DateTime<Utc>) -> Result<(), ProposalsError> {
    let now = Utc::now();
    // A minute of slack so a proposal for "right now" doesn't get rejected
    // by clock skew between phone and server.
    if when < now - Duration::minutes(1) {
        return Err(bad("No se puede proponer una fecha que ya ha pasado"));
    }
    if when > now + Duration::days(365) {
        return Err(bad("La fecha es demasiado lejana"));
    }
    if let Some(name) = &dto.place_name {
        if name.chars().count() > 200 {
            return Err(bad("El nombre del lugar es demasiado largo"));
        }
    }
    // Coordinates only make sense as a pair, and only inside the real
    // ranges — same check the profile location does.
    match (dto.place_lat, dto.place_lng) {
        (Some(lat), Some(lng)) => {
            if !(-90.0..=90.0).contains(&lat) || !(-180.0..=180.0).contains(&lng) {
                return Err(bad("Coordenadas del lugar fuera de rango"));
            }
        }
        (None, None) => {}
        _ => return Err(bad("Faltan coordenadas del lugar")),
    }
    Ok(())
}

pub async fn create(
    state: &AppState,
    match_id: &str,
    user_id: &str,
    dto: CreateProposalDto,
) -> Result<ProposalResponse, ProposalsError> {
    let when = DateTime::parse_from_rfc3339(&dto.scheduled_at)
        .map_err(|_| bad("Fecha inválida"))?
        .with_timezone(&Utc);
    validate(&dto, when)?;

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    let found = assert_member(&mut conn, match_id, user_id).await?;
    assert_both_play(&mut conn, &found, dto.sport).await?;

    // **Una propuesta nueva ya no cancela la que hubiera pendiente.**
    //
    // La regla existia porque una contraoferta es implicitamente un "no" a la
    // anterior, y eso es cierto cuando se esta renegociando *la misma*
    // quedada. Pero impedia lo que la gente quiere hacer de verdad: cerrar el
    // martes y el jueves con la misma persona. Con una sola propuesta viva por
    // match habia que esperar a que aceptaran la primera para poder mandar la
    // segunda.
    //
    // Lo que se pierde: proponer una hora distinta ya no retira la anterior,
    // asi que quedan las dos sobre la mesa y la otra persona podria aceptar la
    // vieja. A cambio, quien propone puede retirarla (`CANCEL`), que es
    // explicito y no adivina intenciones.

    let created = diesel::insert_into(proposals::table)
        .values(NewProposal {
            id: uuid::Uuid::new_v4().to_string(),
            match_id: match_id.to_string(),
            proposed_by_id: user_id.to_string(),
            sport: dto.sport,
            place_name: dto.place_name,
            place_lat: dto.place_lat,
            place_lng: dto.place_lng,
            scheduled_at: when,
            status: ProposalStatus::Pending,
            updated_at: Utc::now(),
        })
        .get_result::<Proposal>(&mut conn)
        .await?;

    // A quien la recibe. Es la notificación más valiosa de la app: una
    // propuesta caduca sola (la fecha pasa), así que enterarse tarde equivale
    // a no enterarse.
    let other_id = if found.user_a_id == user_id {
        found.user_b_id.clone()
    } else {
        found.user_a_id.clone()
    };
    let name = display_name_of(&mut conn, user_id).await;
    crate::push::spawn_notify(
        state,
        &other_id,
        format!("{name} te propone una quedada"),
        when_label(when, created.sport),
        serde_json::json!({
            "type": "proposal",
            "matchId": match_id,
            "proposalId": created.id,
        }),
    );

    Ok(ProposalResponse::from_row(created, user_id))
}

/// Nombre visible de un usuario, con recambio si aún no tiene perfil.
async fn display_name_of(conn: &mut AsyncPgConnection, user_id: &str) -> String {
    profiles::table
        .filter(profiles::user_id.eq(user_id))
        .select(profiles::display_name)
        .first::<String>(conn)
        .await
        .optional()
        .ok()
        .flatten()
        .unwrap_or_else(|| "Alguien".to_string())
}

/// Cuerpo del aviso: qué deporte y cuándo.
///
/// La fecha se da en UTC porque el servidor no sabe en qué huso está quien
/// lee — el cliente ya la muestra bien en la ficha de la quedada, y aquí lo
/// que importa es que se reconozca de un vistazo.
fn when_label(when: DateTime<Utc>, sport: Sport) -> String {
    let que = match sport {
        Sport::Tennis => "Partido de tenis",
        Sport::Running => "Salida a correr",
    };
    format!("{que} · {}", when.format("%d/%m a las %H:%M UTC"))
}

pub async fn list_for_match(
    state: &AppState,
    match_id: &str,
    user_id: &str,
) -> Result<Vec<ProposalResponse>, ProposalsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    assert_member(&mut conn, match_id, user_id).await?;

    let rows = proposals::table
        .filter(proposals::match_id.eq(match_id))
        .order(proposals::created_at.desc())
        .limit(50)
        .load::<Proposal>(&mut conn)
        .await?;

    Ok(rows
        .into_iter()
        .map(|p| ProposalResponse::from_row(p, user_id))
        .collect())
}

pub async fn respond(
    state: &AppState,
    proposal_id: &str,
    user_id: &str,
    action: ProposalAction,
) -> Result<ProposalResponse, ProposalsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    let existing = proposals::table
        .filter(proposals::id.eq(proposal_id))
        .first::<Proposal>(&mut conn)
        .await
        .optional()?
        .ok_or(ProposalsError::NotFound)?;

    // Membership first: a stranger must not even learn this id exists.
    assert_member(&mut conn, &existing.match_id, user_id).await?;

    let is_proposer = existing.proposed_by_id == user_id;
    let new_status = match action {
        ProposalAction::Accept | ProposalAction::Decline => {
            if existing.status != ProposalStatus::Pending {
                return Err(bad("Esta propuesta ya no está pendiente"));
            }
            // Accepting your own proposal would make agreement meaningless.
            if is_proposer {
                return Err(ProposalsError::Forbidden);
            }
            if action == ProposalAction::Accept {
                ProposalStatus::Accepted
            } else {
                ProposalStatus::Declined
            }
        }
        ProposalAction::Cancel => {
            // Cualquiera de los dos puede echarse atrás de algo ya
            // acordado; mientras solo está propuesto, únicamente quien la
            // hizo puede retirarla (la otra parte "rechaza", no "cancela").
            match existing.status {
                ProposalStatus::Pending if !is_proposer => return Err(ProposalsError::Forbidden),
                ProposalStatus::Pending | ProposalStatus::Accepted => {}
                _ => return Err(bad("Esta propuesta ya está cerrada")),
            }
            ProposalStatus::Cancelled
        }
    };

    let updated = diesel::update(proposals::table.filter(proposals::id.eq(proposal_id)))
        .set((
            proposals::status.eq(new_status),
            proposals::updated_at.eq(Utc::now()),
        ))
        .get_result::<Proposal>(&mut conn)
        .await?;

    // Se avisa a la otra parte, sea quien sea: quien propuso necesita saber
    // si hay partido, y quien aceptó necesita enterarse si el otro se echa
    // atrás — presentarse en la pista y que no venga nadie es justo lo que
    // esto evita.
    let other_id = if existing.proposed_by_id == user_id {
        // Cancelación del proponente: hay que avisar al que recibió.
        let m = assert_member(&mut conn, &existing.match_id, user_id).await?;
        if m.user_a_id == user_id {
            m.user_b_id
        } else {
            m.user_a_id
        }
    } else {
        existing.proposed_by_id.clone()
    };

    let name = display_name_of(&mut conn, user_id).await;
    let (titulo, cuerpo) = match new_status {
        // El único aviso que además dice **qué falta hacer**. Aceptar cierra
        // el acuerdo entre dos personas y nada más: la pista sigue sin
        // alquilar, porque la app no reserva nada ni tiene convenio con
        // ningún club. Sin esta coletilla, "ha aceptado" se lee como "ya
        // está" y la forma normal de fallar pasa a ser la peor — los dos
        // aparecen y no hay pista.
        ProposalStatus::Accepted => (
            format!("{name} ha aceptado"),
            format!(
                "{} · Falta reservar la pista",
                when_label(existing.scheduled_at, existing.sport)
            ),
        ),
        ProposalStatus::Declined => (
            format!("{name} no puede"),
            "Propón otro día si te viene mejor".to_string(),
        ),
        _ => (
            format!("{name} ha cancelado la quedada"),
            when_label(existing.scheduled_at, existing.sport),
        ),
    };

    crate::push::spawn_notify(
        state,
        &other_id,
        titulo,
        cuerpo,
        serde_json::json!({
            "type": "proposal",
            "matchId": existing.match_id,
            "proposalId": existing.id,
        }),
    );

    Ok(ProposalResponse::from_row(updated, user_id))
}

/// The caller's whole agenda across every match: sessions already agreed
/// *and* proposals still waiting on someone, as long as they haven't
/// happened yet.
///
/// Pending ones are deliberately included. They used to be reachable only
/// from inside the chat that carried them, so a proposal you hadn't opened
/// yet was invisible in the one screen named after exactly that — you had
/// to remember which conversation it arrived in. The status travels with
/// each row, so the client can group them ("esperando respuesta" vs
/// "confirmadas") without a second call.
pub async fn list_upcoming(
    state: &AppState,
    user_id: &str,
) -> Result<Vec<UpcomingSession>, ProposalsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    // A little grace so a session still shows while it's underway rather
    // than vanishing the instant it starts.
    let cutoff = Utc::now() - Duration::hours(3);

    let rows = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .filter(
            proposals::status
                .eq(ProposalStatus::Accepted)
                .or(proposals::status.eq(ProposalStatus::Pending)),
        )
        .filter(proposals::scheduled_at.ge(cutoff))
        .order(proposals::scheduled_at.asc())
        .limit(50)
        .select((
            proposals::all_columns,
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(Proposal, String, String)>(&mut conn)
        .await?;

    let mut result = Vec::with_capacity(rows.len());
    for (proposal, user_a_id, user_b_id) in rows {
        let other_id = if user_a_id == user_id {
            user_b_id
        } else {
            user_a_id
        };

        let other = profiles::table
            .filter(profiles::user_id.eq(&other_id))
            .select((profiles::display_name, profiles::photos))
            .first::<(String, Vec<String>)>(&mut conn)
            .await
            .optional()?;
        let (other_display_name, other_photo) = match other {
            Some((name, photos)) => (name, photos.into_iter().next()),
            None => ("Sin nombre".to_string(), None),
        };

        result.push(UpcomingSession {
            proposal: ProposalResponse::from_row(proposal, user_id),
            other_user_id: other_id,
            other_display_name,
            other_photo,
        });
    }

    Ok(result)
}

/// Un partido ya jugado, con lo que se contó de él.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PlayedSession {
    #[serde(flatten)]
    pub proposal: ProposalResponse,
    pub other_user_id: String,
    pub other_display_name: String,
    pub other_photo: Option<String>,
    /// Lo que **tú** contaste: si se jugó y cómo acabó. `None` mientras no
    /// hayas respondido — la quedada existe igual, sólo que sin resultado.
    pub played: Option<bool>,
    pub outcome: Option<SessionOutcome>,
}

/// El historial: partidos que ya pasaron, del más reciente al más antiguo.
///
/// Hasta ahora la app tiraba todo lo jugado: `/me/proposals` sólo devuelve lo
/// que está por venir, y en cuanto un partido pasaba desaparecía de la
/// pantalla — con él, la única prueba de que la app sirve para algo. Y los
/// datos estaban ahí: `SessionFeedback` guarda desde hace tiempo si se jugó y
/// quién ganó, pero no había forma de volver a verlos.
///
/// Sólo `ACCEPTED`: una propuesta que nadie aceptó no es un partido, es una
/// propuesta que no salió, y meterla en el historial sería inflar la cuenta.
pub async fn list_history(
    state: &AppState,
    user_id: &str,
) -> Result<Vec<PlayedSession>, ProposalsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    // El mismo margen que `list_upcoming`, para que una quedada no salga a la
    // vez en las dos listas ni desaparezca de las dos durante unas horas.
    let cutoff = Utc::now() - Duration::hours(3);

    let rows = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .filter(proposals::status.eq(ProposalStatus::Accepted))
        .filter(proposals::scheduled_at.lt(cutoff))
        .order(proposals::scheduled_at.desc())
        .limit(100)
        .select((
            proposals::all_columns,
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(Proposal, String, String)>(&mut conn)
        .await?;

    let mut result = Vec::with_capacity(rows.len());
    for (proposal, user_a_id, user_b_id) in rows {
        let other_id = if user_a_id == user_id {
            user_b_id
        } else {
            user_a_id
        };

        let other = profiles::table
            .filter(profiles::user_id.eq(&other_id))
            .select((profiles::display_name, profiles::photos))
            .first::<(String, Vec<String>)>(&mut conn)
            .await
            .optional()?;
        let (other_display_name, other_photo) = match other {
            Some((name, photos)) => (name, photos.into_iter().next()),
            None => ("Sin nombre".to_string(), None),
        };

        // Sólo la fila propia: lo que dijo la otra persona es asunto suyo, y
        // enseñar "dice que ganó él" al lado de "dices que ganaste tú" sería
        // abrir una discusión que la app no puede arbitrar.
        let mine = session_feedback::table
            .filter(session_feedback::proposal_id.eq(&proposal.id))
            .filter(session_feedback::user_id.eq(user_id))
            .select((session_feedback::played, session_feedback::outcome))
            .first::<(bool, Option<SessionOutcome>)>(&mut conn)
            .await
            .optional()?;

        result.push(PlayedSession {
            proposal: ProposalResponse::from_row(proposal, user_id),
            other_user_id: other_id,
            other_display_name,
            other_photo,
            played: mine.map(|(played, _)| played),
            outcome: mine.and_then(|(_, outcome)| outcome),
        });
    }

    Ok(result)
}

// --- Cerrar el bucle: que paso con la quedada ---

/// Quedadas ya pasadas que siguen esperando **tu** respuesta.
///
/// El criterio es deliberadamente estrecho: solo las `ACCEPTED` (las que no
/// se llegaron a aceptar no hay nada que confirmar) cuya hora ya paso con
/// margen, y solo mientras tu no hayas contestado — que la otra persona haya
/// contestado o no es asunto suyo.
pub async fn list_awaiting_feedback(
    state: &AppState,
    user_id: &str,
) -> Result<Vec<UpcomingSession>, ProposalsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    // El mismo margen que usa `list_upcoming` para dejar de considerarla
    // "proxima": asi una quedada nunca esta en las dos listas ni en ninguna.
    let cutoff = Utc::now() - Duration::hours(3);

    // Y un limite por abajo: preguntar por algo de hace tres meses no ayuda
    // a nadie y solo ensucia la pantalla.
    let floor = Utc::now() - Duration::days(30);

    let already_answered = session_feedback::table
        .filter(session_feedback::user_id.eq(user_id))
        .select(session_feedback::proposal_id);

    let rows = proposals::table
        .inner_join(matches::table.on(matches::id.eq(proposals::match_id)))
        .filter(
            matches::user_a_id
                .eq(user_id)
                .or(matches::user_b_id.eq(user_id)),
        )
        .filter(proposals::status.eq(ProposalStatus::Accepted))
        .filter(proposals::scheduled_at.lt(cutoff))
        .filter(proposals::scheduled_at.ge(floor))
        .filter(proposals::id.ne_all(already_answered))
        .order(proposals::scheduled_at.desc())
        .limit(20)
        .select((
            proposals::all_columns,
            matches::user_a_id,
            matches::user_b_id,
        ))
        .load::<(Proposal, String, String)>(&mut conn)
        .await?;

    let mut result = Vec::with_capacity(rows.len());
    for (proposal, user_a_id, user_b_id) in rows {
        let other_id = if user_a_id == user_id {
            user_b_id
        } else {
            user_a_id
        };

        let other = profiles::table
            .filter(profiles::user_id.eq(&other_id))
            .select((profiles::display_name, profiles::photos))
            .first::<(String, Vec<String>)>(&mut conn)
            .await
            .optional()?;
        let (other_display_name, other_photo) = match other {
            Some((name, photos)) => (name, photos.into_iter().next()),
            None => ("Sin nombre".to_string(), None),
        };

        result.push(UpcomingSession {
            proposal: ProposalResponse::from_row(proposal, user_id),
            other_user_id: other_id,
            other_display_name,
            other_photo,
        });
    }

    Ok(result)
}

/// Guarda lo que cuentas de una quedada pasada.
///
/// Es un upsert por (quedada, persona): contestar dos veces corrige la
/// respuesta en vez de acumular filas. Corregirse tiene que ser posible —
/// la primera respuesta suele darse con prisa desde una notificacion.
pub async fn save_feedback(
    state: &AppState,
    proposal_id: &str,
    user_id: &str,
    dto: SessionFeedbackDto,
) -> Result<SessionFeedback, ProposalsError> {
    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| ProposalsError::Pool(e.to_string()))?;

    let proposal = proposals::table
        .filter(proposals::id.eq(proposal_id))
        .first::<Proposal>(&mut conn)
        .await
        .optional()?
        .ok_or(ProposalsError::NotFound)?;

    // Igual que en `respond`: pertenecer al match es lo unico que autoriza.
    assert_member(&mut conn, &proposal.match_id, user_id).await?;

    if proposal.status != ProposalStatus::Accepted {
        return Err(bad(
            "Solo se puede contar que paso en una quedada que se llego a aceptar",
        ));
    }
    if proposal.scheduled_at > Utc::now() {
        return Err(bad("Esta quedada todavia no ha ocurrido"));
    }

    // Saltarla es no decir nada: guardar además un resultado sería una
    // contradicción en la misma fila.
    if dto.skipped
        && (dto.played
            || dto.outcome.is_some()
            || dto.would_repeat.is_some()
            || dto.assessed_level.is_some())
    {
        return Err(bad("Una resena saltada no puede traer respuestas dentro"));
    }
    // Coherencia de la respuesta. Un resultado de un partido que no se jugo
    // seria justo el dato que envenenaria un rating mas adelante.
    if !dto.played
        && (dto.outcome.is_some() || dto.would_repeat.is_some() || dto.assessed_level.is_some())
    {
        return Err(bad(
            "Si la quedada no se jugo no hay resultado ni valoracion que guardar",
        ));
    }
    // Correr no tiene marcador. Aceptar un WON aqui seria guardar algo que no
    // significa nada.
    if dto.outcome.is_some() && proposal.sport != Sport::Tennis {
        return Err(bad("Solo se guarda resultado en los partidos de tenis"));
    }

    let saved = diesel::insert_into(session_feedback::table)
        .values(NewSessionFeedback {
            id: uuid::Uuid::new_v4().to_string(),
            proposal_id: proposal_id.to_string(),
            user_id: user_id.to_string(),
            played: dto.played,
            outcome: dto.outcome,
            would_repeat: dto.would_repeat,
            assessed_level: dto.assessed_level,
            skipped: dto.skipped,
        })
        .on_conflict((session_feedback::proposal_id, session_feedback::user_id))
        .do_update()
        .set((
            session_feedback::played.eq(dto.played),
            session_feedback::outcome.eq(dto.outcome),
            session_feedback::would_repeat.eq(dto.would_repeat),
            session_feedback::assessed_level.eq(dto.assessed_level),
            session_feedback::skipped.eq(dto.skipped),
        ))
        .get_result::<SessionFeedback>(&mut conn)
        .await?;

    Ok(saved)
}
