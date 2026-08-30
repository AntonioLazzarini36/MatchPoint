use serde::Deserialize;
use utoipa::ToSchema;

use crate::models::{SessionOutcome, SkillLevel, Sport};

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

/// Lo que cuentas de una quedada ya pasada.
///
/// `played: false` es una respuesta de primera clase, no un error: que
/// alguien no aparezca es informacion util, y la alternativa (borrar la
/// quedada y hacer como que no existio) esconde justo lo que interesa saber.
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SessionFeedbackDto {
    pub played: bool,
    /// Solo en tenis, y solo si se jugo. Al correr no hay marcador.
    pub outcome: Option<SessionOutcome>,
    /// La senal que de verdad sirve para reencontrarse. Solo si se jugo.
    pub would_repeat: Option<bool>,
    /// Qué nivel te pareció que tenía la otra persona.
    ///
    /// Se manda **el nivel**, no un "correcto/mejor/peor": responder que sí
    /// era el correcto significa mandar el nivel que esa persona declara, que
    /// es lo mismo dicho de otra forma. Así el veredicto se calcula al leer,
    /// contra lo que declare en ese momento, y no se queda congelado contra
    /// un nivel que a lo mejor ya cambió.
    pub assessed_level: Option<SkillLevel>,
    /// La reseña se salta. Deja constancia sin afirmar nada, para que esa
    /// quedada deje de pedir respuesta.
    ///
    /// Existe porque obligar a contestar es la forma más rápida de que la
    /// gente conteste cualquier cosa por quitárselo de encima — y este dato
    /// sostiene el nivel de todos los demás.
    #[serde(default)]
    pub skipped: bool,
}
