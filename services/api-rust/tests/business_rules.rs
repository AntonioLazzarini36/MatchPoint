//! Las reglas de negocio que ya se rompieron una vez.
//!
//! No es cobertura por cobertura: cada test de aquí corresponde a un fallo
//! real que llegó a producción y que costó un rato encontrar. Ver el
//! historial de `feature/rust-backend`:
//!
//! - El match no saltaba entre deportes distintos: dos personas que juegan a
//!   los dos se daban like en feeds distintos y no pasaba nada, mientras "te
//!   ha dado like" sí aparecía y prometía un match que no llegaba.
//! - `/discover` filtraba por deporte sólo a los candidatos y no a quien
//!   miraba, así que salían matches sin ningún deporte en común — matches que
//!   no pueden acabar en ninguna quedada.
//! - `Match.sport` decidía qué se podía proponer, en vez de lo que practican
//!   las dos personas.

mod common;

use common::{cleanup, make_user, test_state};
use matchpoint_api::models::{Sport, SwipeType};
use matchpoint_api::proposals::dto::{CreateProposalDto, ProposalAction};
use matchpoint_api::swipes::dto::CreateSwipeDto;
use matchpoint_api::{discover, proposals, swipes};

fn like(to: &str, sport: Sport) -> CreateSwipeDto {
    CreateSwipeDto {
        to_user_id: to.to_string(),
        sport,
        swipe_type: SwipeType::Like,
    }
}

// --- Swipes y matches ---

/// El fallo original: el match exigía que los dos likes fueran del mismo
/// deporte. Cada uno elige por su cuenta qué feed mira, así que dos personas
/// que juegan a ambos se daban like en deportes distintos y no pasaba nada.
#[tokio::test]
async fn el_like_reciproco_hace_match_aunque_sea_en_deportes_distintos() {
    let state = test_state().await;
    let a = make_user(&state, "a", &[Sport::Tennis, Sport::Running]).await;
    let b = make_user(&state, "b", &[Sport::Tennis, Sport::Running]).await;

    let first = swipes::service::create_swipe(&state, &a, like(&b, Sport::Tennis))
        .await
        .expect("primer like");
    assert!(!first.matched, "un like solo no puede hacer match");

    let second = swipes::service::create_swipe(&state, &b, like(&a, Sport::Running))
        .await
        .expect("segundo like");
    assert!(
        second.matched,
        "el like de vuelta debe contar aunque sea de otro deporte"
    );

    cleanup(&state, &[&a, &b]).await;
}

/// Y el corolario: dos personas no pueden acabar con dos matches (y dos
/// chats) por darse like en los dos deportes. La unique de la tabla es por
/// (userA, userB, sport), así que no lo impide sola.
#[tokio::test]
async fn dos_personas_no_acumulan_dos_matches() {
    let state = test_state().await;
    let a = make_user(&state, "a", &[Sport::Tennis, Sport::Running]).await;
    let b = make_user(&state, "b", &[Sport::Tennis, Sport::Running]).await;

    swipes::service::create_swipe(&state, &a, like(&b, Sport::Tennis))
        .await
        .unwrap();
    let first = swipes::service::create_swipe(&state, &b, like(&a, Sport::Tennis))
        .await
        .unwrap();

    // Ahora se dan like también en el otro deporte.
    swipes::service::create_swipe(&state, &a, like(&b, Sport::Running))
        .await
        .unwrap();
    let second = swipes::service::create_swipe(&state, &b, like(&a, Sport::Running))
        .await
        .unwrap();

    assert_eq!(
        first.match_id, second.match_id,
        "el segundo deporte debe reutilizar el match, no crear otro"
    );

    cleanup(&state, &[&a, &b]).await;
}

// --- Discover ---

/// El agujero real: el filtro de deporte se aplicaba sólo a los candidatos.
/// Pedir `?sport=RUNNING` jugando sólo al tenis devolvía corredores, y de ahí
/// salían matches sin ningún deporte en común.
#[tokio::test]
async fn discover_rechaza_un_deporte_que_no_juegas() {
    let state = test_state().await;
    let solo_tenis = make_user(&state, "solotenis", &[Sport::Tennis]).await;

    let res = discover::service::discover(&state, &solo_tenis, Some(Sport::Running)).await;
    assert!(
        res.is_err(),
        "pedir un deporte que no juegas tiene que fallar, no devolver gente"
    );

    cleanup(&state, &[&solo_tenis]).await;
}

/// Sin `?sport=`, sólo debe salir quien comparta alguno de tus deportes.
#[tokio::test]
async fn discover_solo_ensena_a_quien_comparte_deporte() {
    let state = test_state().await;
    let yo = make_user(&state, "yo", &[Sport::Tennis]).await;
    let comparte = make_user(&state, "comparte", &[Sport::Tennis]).await;
    let no_comparte = make_user(&state, "nocomparte", &[Sport::Running]).await;

    let found = discover::service::discover(&state, &yo, None)
        .await
        .expect("discover");
    let ids: Vec<&str> = found.iter().map(|p| p.user_id.as_str()).collect();

    assert!(
        ids.contains(&comparte.as_str()),
        "debe salir quien comparte"
    );
    assert!(
        !ids.contains(&no_comparte.as_str()),
        "no debe salir quien no comparte ningun deporte"
    );

    cleanup(&state, &[&yo, &comparte, &no_comparte]).await;
}

/// A quien ya has deslizado no se le vuelve a ver: sin esto el feed te
/// devuelve a la misma persona una y otra vez.
#[tokio::test]
async fn discover_no_repite_a_quien_ya_deslizaste() {
    let state = test_state().await;
    let yo = make_user(&state, "yo", &[Sport::Tennis]).await;
    let otro = make_user(&state, "otro", &[Sport::Tennis]).await;

    let before = discover::service::discover(&state, &yo, None)
        .await
        .unwrap();
    assert!(before.iter().any(|p| p.user_id == otro));

    swipes::service::create_swipe(
        &state,
        &yo,
        CreateSwipeDto {
            to_user_id: otro.clone(),
            sport: Sport::Tennis,
            swipe_type: SwipeType::Pass,
        },
    )
    .await
    .unwrap();

    let after = discover::service::discover(&state, &yo, None)
        .await
        .unwrap();
    assert!(
        !after.iter().any(|p| p.user_id == otro),
        "tras deslizar, esa persona no debe volver a salir"
    );

    cleanup(&state, &[&yo, &otro]).await;
}

// --- Propuestas ---

async fn matched_pair(
    state: &matchpoint_api::state::AppState,
    a_sports: &[Sport],
    b_sports: &[Sport],
) -> (String, String, String) {
    let a = make_user(state, "pa", a_sports).await;
    let b = make_user(state, "pb", b_sports).await;
    swipes::service::create_swipe(state, &a, like(&b, Sport::Tennis))
        .await
        .unwrap();
    let res = swipes::service::create_swipe(state, &b, like(&a, Sport::Tennis))
        .await
        .unwrap();
    (a, b, res.match_id.expect("match"))
}

fn proposal(sport: Sport, hours: i64) -> CreateProposalDto {
    CreateProposalDto {
        sport,
        place_name: Some("Pista central".to_string()),
        place_lat: None,
        place_lng: None,
        scheduled_at: (chrono::Utc::now() + chrono::Duration::hours(hours)).to_rfc3339(),
    }
}

/// Lo que decide qué se puede proponer es lo que practican **las dos
/// personas**, no `Match.sport`. Antes, dos que jugaban a ambos sólo podían
/// proponer el deporte del match.
#[tokio::test]
async fn se_puede_proponer_cualquier_deporte_que_practiquen_los_dos() {
    let state = test_state().await;
    let (a, b, match_id) = matched_pair(
        &state,
        &[Sport::Tennis, Sport::Running],
        &[Sport::Tennis, Sport::Running],
    )
    .await;

    // El match nació de un like en tenis, pero los dos corren.
    proposals::service::create(&state, &match_id, &a, proposal(Sport::Running, 24))
        .await
        .expect("correr deberia valer: lo practican los dos");

    cleanup(&state, &[&a, &b]).await;
}

/// Y al reves: proponerle a alguien un deporte que no practica es una
/// quedada que no va a existir.
#[tokio::test]
async fn no_se_puede_proponer_un_deporte_que_el_otro_no_juega() {
    let state = test_state().await;
    let (a, b, match_id) = matched_pair(
        &state,
        &[Sport::Tennis, Sport::Running],
        &[Sport::Tennis], // b solo juega al tenis
    )
    .await;

    let res = proposals::service::create(&state, &match_id, &a, proposal(Sport::Running, 24)).await;
    assert!(
        res.is_err(),
        "el otro no corre: no deberia poder proponerse"
    );

    cleanup(&state, &[&a, &b]).await;
}

/// Aceptar tu propia propuesta vaciaría de sentido el acuerdo.
#[tokio::test]
async fn nadie_acepta_su_propia_propuesta() {
    let state = test_state().await;
    let (a, b, match_id) = matched_pair(&state, &[Sport::Tennis], &[Sport::Tennis]).await;

    let created = proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 24))
        .await
        .unwrap();

    let mine = proposals::service::respond(&state, &created.id, &a, ProposalAction::Accept).await;
    assert!(mine.is_err(), "quien propone no puede aceptar");

    let theirs = proposals::service::respond(&state, &created.id, &b, ProposalAction::Accept).await;
    assert!(theirs.is_ok(), "quien la recibe si puede aceptar");

    cleanup(&state, &[&a, &b]).await;
}

/// Una contraoferta es implícitamente un "no" a la anterior: dos propuestas
/// vivas a la vez dejarían a los dos preguntándose cuál están aceptando.
#[tokio::test]
async fn una_propuesta_nueva_cancela_la_pendiente() {
    let state = test_state().await;
    let (a, b, match_id) = matched_pair(&state, &[Sport::Tennis], &[Sport::Tennis]).await;

    proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 24))
        .await
        .unwrap();
    proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 48))
        .await
        .unwrap();

    let all = proposals::service::list_for_match(&state, &match_id, &a)
        .await
        .unwrap();
    let pending = all
        .iter()
        .filter(|p| p.status == matchpoint_api::models::ProposalStatus::Pending)
        .count();
    assert_eq!(pending, 1, "solo puede quedar una propuesta viva");

    cleanup(&state, &[&a, &b]).await;
}

/// Cancelar una quedada ya acordada puede hacerlo cualquiera de los dos: los
/// planes cambian, y obligar a alguien a simplemente no aparecer es peor.
#[tokio::test]
async fn cualquiera_cancela_una_quedada_ya_aceptada() {
    let state = test_state().await;
    let (a, b, match_id) = matched_pair(&state, &[Sport::Tennis], &[Sport::Tennis]).await;

    let created = proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 24))
        .await
        .unwrap();
    proposals::service::respond(&state, &created.id, &b, ProposalAction::Accept)
        .await
        .unwrap();

    // La cancela quien la recibio, no quien la propuso.
    let cancelled = proposals::service::respond(&state, &created.id, &b, ProposalAction::Cancel)
        .await
        .expect("cancelar una aceptada debe poder hacerlo cualquiera de los dos");
    assert_eq!(
        cancelled.status,
        matchpoint_api::models::ProposalStatus::Cancelled
    );

    cleanup(&state, &[&a, &b]).await;
}
