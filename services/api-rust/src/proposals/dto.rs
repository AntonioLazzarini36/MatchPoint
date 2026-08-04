use serde::Deserialize;
use utoipa::ToSchema;

use crate::models::Sport;

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CreateProposalDto {
    /// Which sport this session is for. Validated against the match's own
    /// sport in `service.rs` — you can't propose a run inside a tennis
    /// match.
    pub sport: Sport,
    /// Display name of the place, mirroring how `Profile.city` doubles as
    /// the label of a picked location. Optional: "ya vemos dónde" is a
    /// legitimate proposal.
    pub place_name: Option<String>,
    pub place_lat: Option<f64>,
    pub place_lng: Option<f64>,
    /// ISO-8601 with offset, e.g. `2026-08-06T19:00:00Z`.
    pub scheduled_at: String,
}

/// The only transition a client can ask for directly. Which ones are
/// actually legal depends on who is asking — see `service::respond`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, ToSchema)]
#[serde(rename_all = "UPPERCASE")]
pub enum ProposalAction {
    Accept,
    Decline,
    Cancel,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RespondProposalDto {
    pub action: ProposalAction,
}
