//! Direct port of swipes.service.ts.

use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::RunQueryDsl;
use serde::Serialize;
use utoipa::ToSchema;

use crate::models::{Match, NewMatch, NewSwipe, Sport, SwipeType};
use crate::schema::{matches, profiles, swipes};
use crate::state::AppState;
use crate::swipes::dto::CreateSwipeDto;

#[derive(Debug, thiserror::Error)]
pub enum SwipesError {
    #[error("Cannot swipe yourself")]
    CannotSwipeSelf,
    #[error("Database error: {0}")]
    Db(#[from] diesel::result::Error),
    #[error("Connection pool error: {0}")]
    Pool(String),
}

/// Mirrors the two possible shapes `swipes.service.ts` returns:
/// `{ match: false, swipeId }` or `{ match: true, matchId, swipeId }`.
/// `matched` is the Rust field name because `match` is a reserved
/// keyword; `#[serde(rename = "match")]` puts the JSON key back to what
/// the TS version (and therefore Flutter) expects.
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SwipeResult {
    #[serde(rename = "match")]
    pub matched: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub match_id: Option<String>,
    pub swipe_id: String,
}

/// Equivalent of the private `orderPair` helper in swipes.service.ts —
/// Match rows always store the lexicographically-smaller id as userAId,
/// so a mutual like from either direction lands on the same row.
fn order_pair(a: &str, b: &str, sport: Sport) -> (String, String, Sport) {
    if a < b {
        (a.to_string(), b.to_string(), sport)
    } else {
        (b.to_string(), a.to_string(), sport)
    }
}

pub async fn create_swipe(
    state: &AppState,
    from_user_id: &str,
    dto: CreateSwipeDto,
) -> Result<SwipeResult, SwipesError> {
    if dto.to_user_id == from_user_id {
        return Err(SwipesError::CannotSwipeSelf);
    }

    let mut conn = state
        .db
        .get()
        .await
        .map_err(|e| SwipesError::Pool(e.to_string()))?;

    // Upsert the swipe: unique on (fromUserId, toUserId, sport), same
    // constraint Prisma's `swipe.upsert` relies on.
    let swipe_id = diesel::insert_into(swipes::table)
        .values(NewSwipe {
            id: uuid::Uuid::new_v4().to_string(),
            from_user_id: from_user_id.to_string(),
            to_user_id: dto.to_user_id.clone(),
            sport: dto.sport,
            swipe_type: dto.swipe_type,
        })
        .on_conflict((swipes::from_user_id, swipes::to_user_id, swipes::sport))
        .do_update()
        .set(swipes::swipe_type.eq(dto.swipe_type))
        .returning(swipes::id)
        .get_result::<String>(&mut conn)
        .await?;

    if dto.swipe_type != SwipeType::Like {
        return Ok(SwipeResult {
            matched: false,
            match_id: None,
            swipe_id,
        });
    }

    // El like de vuelta cuenta **sea del deporte que sea**.
    //
    // Antes se exigía el mismo deporte, y eso rompía el match entre dos
    // personas que juegan a los dos: cada una elige por su cuenta qué feed
    // está mirando, así que una daba like en tenis y la otra en correr y no
    // pasaba nada — con el agravante de que "te ha dado like" sí salía
    // (cuando mirabas el feed del deporte correcto) y el match no llegaba
    // nunca. Un like significa "quiero jugar contigo", no "quiero jugar
    // contigo exactamente a esto": desde que `/discover` sólo enseña a
    // quien comparte deporte contigo, un like recíproco ya implica que hay
    // al menos uno en común, que es lo único que hace falta para quedar.
    let reverse = swipes::table
        .filter(swipes::from_user_id.eq(&dto.to_user_id))
        .filter(swipes::to_user_id.eq(from_user_id))
        .filter(swipes::swipe_type.eq(SwipeType::Like))
        .order(swipes::created_at.desc())
        .select(swipes::id)
        .first::<String>(&mut conn)
        .await
        .optional()?;

    if reverse.is_none() {
        return Ok(SwipeResult {
            matched: false,
            match_id: None,
            swipe_id,
        });
    }

    let (user_a_id, user_b_id, sport) = order_pair(from_user_id, &dto.to_user_id, dto.sport);

    // ¿Ya hay match con esta persona, aunque fuera por el otro deporte?
    // Sin esta comprobación, dos que juegan a ambos acabarían con dos
    // matches y dos chats separados con la misma persona. La unique de la
    // tabla es por (userA, userB, sport), así que no lo impide sola.
    let existing = matches::table
        .filter(matches::user_a_id.eq(&user_a_id))
        .filter(matches::user_b_id.eq(&user_b_id))
        .order(matches::created_at.asc())
        .first::<Match>(&mut conn)
        .await
        .optional()?;

    if let Some(found) = existing {
        return Ok(SwipeResult {
            matched: true,
            match_id: Some(found.id),
            swipe_id,
        });
    }

    // Upsert the match. Prisma's `update: {}` is a no-op update that
    // still returns the existing row; `.set(matches::sport.eq(sport))`
    // here is the same trick — a harmless no-op set (sport can't actually
    // change) purely so `.get_result()` gives us the row back either way,
    // instead of `do_nothing()`, which wouldn't return anything on conflict.
    let saved_match = diesel::insert_into(matches::table)
        .values(NewMatch {
            id: uuid::Uuid::new_v4().to_string(),
            user_a_id: user_a_id.clone(),
            user_b_id: user_b_id.clone(),
            sport,
        })
        .on_conflict((matches::user_a_id, matches::user_b_id, matches::sport))
        .do_update()
        .set(matches::sport.eq(sport))
        .get_result::<Match>(&mut conn)
        .await?;

    // Sólo se avisa al **otro**: quien acaba de deslizar ya está mirando la
    // pantalla y verá el match al instante. Y sólo aquí, en el match recién
    // creado — el `return` de más arriba (match que ya existía) no debe
    // volver a avisar de algo de hace semanas.
    let name = profiles::table
        .filter(profiles::user_id.eq(from_user_id))
        .select(profiles::display_name)
        .first::<String>(&mut conn)
        .await
        .optional()?
        .unwrap_or_else(|| "Alguien".to_string());

    crate::push::spawn_notify(
        state,
        &dto.to_user_id,
        "¡Nuevo match!".to_string(),
        format!("{name} también quiere jugar contigo"),
        serde_json::json!({ "type": "match", "matchId": saved_match.id }),
    );

    Ok(SwipeResult {
        matched: true,
        match_id: Some(saved_match.id),
        swipe_id,
    })
}
