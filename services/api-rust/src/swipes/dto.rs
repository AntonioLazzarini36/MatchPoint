//! Direct port of swipes/dto.ts.

use serde::Deserialize;

use crate::models::{Sport, SwipeType};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateSwipeDto {
    pub to_user_id: String,
    pub sport: Sport,

    // The JSON field is "type" (matches CreateSwipeDto.type in swipes/dto.ts),
    // but `type` is a reserved keyword in Rust, so the Rust-side field is
    // named `swipe_type` and we tell serde to map it back to "type" on
    // the wire. #[serde(rename_all = "camelCase")] on the struct would
    // otherwise turn `swipe_type` into "swipeType", which is wrong here —
    // this explicit `rename` overrides that for just this one field.
    #[serde(rename = "type")]
    pub swipe_type: SwipeType,
}