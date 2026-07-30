//! Direct port of chats/dto.ts. Length validation (1-2000 chars in the
//! TS version's @MinLength/@MaxLength) isn't free with serde, so it's
//! enforced by hand in service.rs instead of here.

use serde::Deserialize;
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub struct SendMessageDto {
    pub text: String,
}
