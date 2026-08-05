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

use crate::models::{Match, NewProposal, Proposal, ProposalStatus, Sport};
use crate::proposals::dto::{CreateProposalDto, ProposalAction};
use crate::schema::{matches, profiles, proposals};
use crate::state::AppState;

#[derive(Debug, thiserror::Error)]
pub enum ProposalsError {
    #[error("Match not found")]
    MatchNotFound,
    #[error("Proposal not found")]
    NotFound,
    #[error("Not allowed")]
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

    // Supersede whatever was still on the table (see module docs).
    diesel::update(
        proposals::table
            .filter(proposals::match_id.eq(match_id))
            .filter(proposals::status.eq(ProposalStatus::Pending)),
    )
    .set((
        proposals::status.eq(ProposalStatus::Cancelled),
        proposals::updated_at.eq(Utc::now()),
    ))
    .execute(&mut conn)
    .await?;

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

    Ok(ProposalResponse::from_row(created, user_id))
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
