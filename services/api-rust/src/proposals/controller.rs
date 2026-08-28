//! HTTP surface for proposals. Routes are split between the match they
//! belong to (create/list) and the proposal itself (respond), plus one
//! `/me`-flavoured route for "what am I playing next".

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, patch, post},
    Json, Router,
};

use crate::auth::jwt::AuthUser;
#[allow(unused_imports)]
use crate::models::SessionFeedback;
#[allow(unused_imports)] // referenced only inside #[utoipa::path] bodies
use crate::openapi::ErrorResponse;
use crate::proposals::dto::{CreateProposalDto, RespondProposalDto, SessionFeedbackDto};
use crate::proposals::service::{self, ProposalsError};
#[allow(unused_imports)]
use crate::proposals::service::{PlayedSession, ProposalResponse, UpcomingSession};
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/matches/:matchId/proposals",
            get(list_for_match).post(create),
        )
        .route("/proposals/:proposalId", patch(respond))
        .route("/me/proposals", get(list_upcoming))
        .route("/me/proposals/history", get(list_history))
        // Separado de `/me/proposals` a proposito: son dos preguntas
        // distintas ("que tengo por jugar" y "que tengo por contar") y
        // mezclarlas obligaria al cliente a filtrar por fecha.
        .route("/me/sessions/played", get(list_awaiting_feedback))
        .route("/proposals/:proposalId/feedback", post(save_feedback))
}

#[utoipa::path(
    post,
    path = "/matches/{matchId}/proposals",
    tag = "proposals",
    security(("bearerAuth" = [])),
    params(("matchId" = String, Path, description = "Id del match")),
    request_body = CreateProposalDto,
    responses(
        (status = 200, description = "Propuesta creada (cualquier propuesta pendiente previa del match queda cancelada)", body = ProposalResponse),
        (status = 400, description = "Fecha, lugar o deporte inválidos", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres miembro de este match", body = ErrorResponse),
        (status = 404, description = "Match no encontrado", body = ErrorResponse),
    )
)]
async fn create(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
    Json(dto): Json<CreateProposalDto>,
) -> impl IntoResponse {
    match service::create(&state, &match_id, &user.user_id, dto).await {
        Ok(proposal) => Json(proposal).into_response(),
        Err(err) => error_response(err),
    }
}

#[utoipa::path(
    get,
    path = "/matches/{matchId}/proposals",
    tag = "proposals",
    security(("bearerAuth" = [])),
    params(("matchId" = String, Path, description = "Id del match")),
    responses(
        (status = 200, description = "Propuestas del match, más reciente primero", body = Vec<ProposalResponse>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres miembro de este match", body = ErrorResponse),
        (status = 404, description = "Match no encontrado", body = ErrorResponse),
    )
)]
async fn list_for_match(
    State(state): State<AppState>,
    user: AuthUser,
    Path(match_id): Path<String>,
) -> impl IntoResponse {
    match service::list_for_match(&state, &match_id, &user.user_id).await {
        Ok(list) => Json(list).into_response(),
        Err(err) => error_response(err),
    }
}

#[utoipa::path(
    patch,
    path = "/proposals/{proposalId}",
    tag = "proposals",
    security(("bearerAuth" = [])),
    params(("proposalId" = String, Path, description = "Id de la propuesta")),
    request_body = RespondProposalDto,
    responses(
        (status = 200, description = "Propuesta actualizada", body = ProposalResponse),
        (status = 400, description = "La propuesta ya no está pendiente", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "Acción no permitida para ti (solo quien la recibió puede aceptar/rechazar; solo quien la hizo puede cancelar)", body = ErrorResponse),
        (status = 404, description = "Propuesta no encontrada", body = ErrorResponse),
    )
)]
async fn respond(
    State(state): State<AppState>,
    user: AuthUser,
    Path(proposal_id): Path<String>,
    Json(dto): Json<RespondProposalDto>,
) -> impl IntoResponse {
    match service::respond(&state, &proposal_id, &user.user_id, dto.action).await {
        Ok(proposal) => Json(proposal).into_response(),
        Err(err) => error_response(err),
    }
}

#[utoipa::path(
    get,
    path = "/me/proposals",
    tag = "proposals",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Agenda del usuario: sesiones aceptadas y propuestas pendientes aún por jugar, más próxima primero", body = Vec<UpcomingSession>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn list_upcoming(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::list_upcoming(&state, &user.user_id).await {
        Ok(list) => Json(list).into_response(),
        Err(err) => error_response(err),
    }
}

#[utoipa::path(
    get,
    path = "/me/proposals/history",
    tag = "proposals",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Partidos ya jugados, del mas reciente al mas antiguo", body = Vec<PlayedSession>),
        (status = 401, description = "Token ausente o invalido", body = ErrorResponse),
    )
)]
async fn list_history(State(state): State<AppState>, user: AuthUser) -> impl IntoResponse {
    match service::list_history(&state, &user.user_id).await {
        Ok(sessions) => Json(sessions).into_response(),
        Err(err) => crate::http_error::respond(StatusCode::INTERNAL_SERVER_ERROR, err),
    }
}

fn error_response(err: ProposalsError) -> axum::response::Response {
    let status = match &err {
        ProposalsError::MatchNotFound | ProposalsError::NotFound => StatusCode::NOT_FOUND,
        ProposalsError::Forbidden => StatusCode::FORBIDDEN,
        ProposalsError::InvalidInput(_) => StatusCode::BAD_REQUEST,
        ProposalsError::Db(_) | ProposalsError::Pool(_) => {
            tracing::error!("proposals error: {err}");
            StatusCode::INTERNAL_SERVER_ERROR
        }
    };
    crate::http_error::respond(status, err)
}

/// Quedadas ya pasadas que siguen esperando que cuentes que ocurrio.
#[utoipa::path(
    get,
    path = "/me/sessions/played",
    tag = "proposals",
    security(("bearerAuth" = [])),
    responses(
        (status = 200, description = "Quedadas pasadas sin contestar", body = Vec<UpcomingSession>),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
    )
)]
async fn list_awaiting_feedback(
    State(state): State<AppState>,
    user: AuthUser,
) -> impl IntoResponse {
    match service::list_awaiting_feedback(&state, &user.user_id).await {
        Ok(list) => Json(list).into_response(),
        Err(e) => error_response(e),
    }
}

/// Guarda que paso en una quedada. Contestar de nuevo corrige la respuesta.
#[utoipa::path(
    post,
    path = "/proposals/{proposalId}/feedback",
    tag = "proposals",
    security(("bearerAuth" = [])),
    params(("proposalId" = String, Path, description = "Id de la quedada")),
    request_body = SessionFeedbackDto,
    responses(
        (status = 200, description = "Respuesta guardada", body = SessionFeedback),
        (status = 400, description = "Respuesta incoherente o quedada aún no ocurrida", body = ErrorResponse),
        (status = 401, description = "Token ausente o inválido", body = ErrorResponse),
        (status = 403, description = "No eres parte de ese match", body = ErrorResponse),
        (status = 404, description = "Quedada no encontrada", body = ErrorResponse),
    )
)]
async fn save_feedback(
    State(state): State<AppState>,
    user: AuthUser,
    Path(proposal_id): Path<String>,
    Json(dto): Json<SessionFeedbackDto>,
) -> impl IntoResponse {
    match service::save_feedback(&state, &proposal_id, &user.user_id, dto).await {
        Ok(saved) => Json(saved).into_response(),
        Err(e) => error_response(e),
    }
}
