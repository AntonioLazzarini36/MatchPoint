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

use common::{
    age_proposal, age_swipe, cleanup, fresh_cluster, make_user, set_availability,
    set_level_and_intention, test_state,
};
use matchpoint_api::discover::service::DiscoverFilters;
use matchpoint_api::matches;
use matchpoint_api::models::{Intention, SkillLevel, Sport, SwipeType};
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
    let c = fresh_cluster();
    let a = make_user(&state, c, "a", &[Sport::Tennis, Sport::Running]).await;
    let b = make_user(&state, c, "b", &[Sport::Tennis, Sport::Running]).await;

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
    let c = fresh_cluster();
    let a = make_user(&state, c, "a", &[Sport::Tennis, Sport::Running]).await;
    let b = make_user(&state, c, "b", &[Sport::Tennis, Sport::Running]).await;

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
    let c = fresh_cluster();
    let solo_tenis = make_user(&state, c, "solotenis", &[Sport::Tennis]).await;

    let res = discover::service::discover(
        &state,
        &solo_tenis,
        DiscoverFilters::for_sport(Sport::Running),
    )
    .await;
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
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let comparte = make_user(&state, c, "comparte", &[Sport::Tennis]).await;
    let no_comparte = make_user(&state, c, "nocomparte", &[Sport::Running]).await;

    let found = discover::service::discover(&state, &yo, DiscoverFilters::default())
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
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let otro = make_user(&state, c, "otro", &[Sport::Tennis]).await;

    let before = discover::service::discover(&state, &yo, DiscoverFilters::default())
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

    let after = discover::service::discover(&state, &yo, DiscoverFilters::default())
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
    cluster: (f64, f64),
    a_sports: &[Sport],
    b_sports: &[Sport],
) -> (String, String, String) {
    let a = make_user(state, cluster, "pa", a_sports).await;
    let b = make_user(state, cluster, "pb", b_sports).await;
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
    let c = fresh_cluster();
    let (a, b, match_id) = matched_pair(
        &state,
        c,
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
    let c = fresh_cluster();
    let (a, b, match_id) = matched_pair(
        &state,
        c,
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
    let c = fresh_cluster();
    let (a, b, match_id) = matched_pair(&state, c, &[Sport::Tennis], &[Sport::Tennis]).await;

    let created = proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 24))
        .await
        .unwrap();

    let mine = proposals::service::respond(&state, &created.id, &a, ProposalAction::Accept).await;
    assert!(mine.is_err(), "quien propone no puede aceptar");

    let theirs = proposals::service::respond(&state, &created.id, &b, ProposalAction::Accept).await;
    assert!(theirs.is_ok(), "quien la recibe si puede aceptar");

    cleanup(&state, &[&a, &b]).await;
}

/// Se pueden tener **varios partidos abiertos con la misma persona**.
///
/// Antes, crear una propuesta cancelaba la pendiente: la idea era que una
/// contraoferta es implícitamente un "no" a la anterior. Cierto cuando se
/// renegocia la misma quedada, y falso para lo que la gente hace de verdad —
/// cerrar el martes y el jueves con el mismo compañero. Con la regla vieja
/// había que esperar a que aceptaran la primera para poder mandar la segunda.
#[tokio::test]
async fn se_pueden_tener_varias_propuestas_vivas_con_la_misma_persona() {
    let state = test_state().await;
    let c = fresh_cluster();
    let (a, b, match_id) = matched_pair(&state, c, &[Sport::Tennis], &[Sport::Tennis]).await;

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
    assert_eq!(pending, 2, "las dos siguen en pie, cada una con su fecha");

    cleanup(&state, &[&a, &b]).await;
}

/// El historial: lo ya jugado no puede desaparecer de la app.
///
/// Sólo entra lo `ACCEPTED` y ya pasado — una propuesta que nadie aceptó no
/// es un partido, es una propuesta que no salió.
#[tokio::test]
async fn el_historial_trae_lo_jugado_y_no_lo_que_esta_por_venir() {
    let state = test_state().await;
    let c = fresh_cluster();
    let (a, b, match_id) = matched_pair(&state, c, &[Sport::Tennis], &[Sport::Tennis]).await;

    // Uno por venir, aceptado.
    let futuro = proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 48))
        .await
        .unwrap();
    proposals::service::respond(&state, &futuro.id, &b, ProposalAction::Accept)
        .await
        .unwrap();

    // Y otro que ya pasó. `create` no admite fechas pasadas (con razón), así
    // que se acepta y se le mueve la fecha por debajo, que es lo que habría
    // pasado solo con el tiempo.
    let pasado = proposals::service::create(&state, &match_id, &a, proposal(Sport::Tennis, 24))
        .await
        .unwrap();
    proposals::service::respond(&state, &pasado.id, &b, ProposalAction::Accept)
        .await
        .unwrap();
    age_proposal(&state, &pasado.id, 72).await;

    let history = proposals::service::list_history(&state, &a).await.unwrap();
    let ids: Vec<&str> = history.iter().map(|s| s.proposal.id.as_str()).collect();

    assert!(
        ids.contains(&pasado.id.as_str()),
        "lo jugado tiene que salir"
    );
    assert!(
        !ids.contains(&futuro.id.as_str()),
        "lo que aun no ha pasado es agenda, no historial"
    );

    cleanup(&state, &[&a, &b]).await;
}

/// Cancelar una quedada ya acordada puede hacerlo cualquiera de los dos: los
/// planes cambian, y obligar a alguien a simplemente no aparecer es peor.
#[tokio::test]
async fn cualquiera_cancela_una_quedada_ya_aceptada() {
    let state = test_state().await;
    let c = fresh_cluster();
    let (a, b, match_id) = matched_pair(&state, c, &[Sport::Tennis], &[Sport::Tennis]).await;

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

/// El caso que motiva `goal_fit`: quien dice que quiere **mejorar de nivel**
/// está pidiendo, literalmente, jugar con alguien mejor. El feed le ponía
/// primero a los de su mismo nivel — justo lo contrario de lo que pidió.
#[tokio::test]
async fn quien_quiere_mejorar_ve_antes_a_alguien_mejor() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "learner", &[Sport::Tennis]).await;
    let igual = make_user(&state, c, "igual", &[Sport::Tennis]).await;
    let mejor = make_user(&state, c, "mejor", &[Sport::Tennis]).await;

    set_level_and_intention(
        &state,
        &yo,
        Sport::Tennis,
        SkillLevel::Intermediate,
        Some(Intention::Learn),
    )
    .await;
    set_level_and_intention(
        &state,
        &igual,
        Sport::Tennis,
        SkillLevel::Intermediate,
        None,
    )
    .await;
    set_level_and_intention(&state, &mejor, Sport::Tennis, SkillLevel::Advanced, None).await;

    let found = discover::service::discover(&state, &yo, DiscoverFilters::for_sport(Sport::Tennis))
        .await
        .expect("discover");

    let pos = |id: &str| found.iter().position(|p| p.user_id == id);
    let (p_mejor, p_igual) = (pos(&mejor), pos(&igual));
    assert!(
        p_mejor.is_some() && p_igual.is_some(),
        "los dos deben salir"
    );
    assert!(
        p_mejor < p_igual,
        "queriendo mejorar, alguien de nivel superior tiene que ir antes que uno de tu mismo nivel"
    );

    cleanup(&state, &[&yo, &igual, &mejor]).await;
}

/// Y el contrario, para que quede claro que la inversión es sólo para
/// `Learn`: quien viene a competir sí quiere a alguien de su nivel.
#[tokio::test]
async fn quien_viene_a_competir_ve_antes_a_alguien_de_su_nivel() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "comp", &[Sport::Tennis]).await;
    let igual = make_user(&state, c, "cigual", &[Sport::Tennis]).await;
    let mejor = make_user(&state, c, "cmejor", &[Sport::Tennis]).await;

    set_level_and_intention(
        &state,
        &yo,
        Sport::Tennis,
        SkillLevel::Intermediate,
        Some(Intention::Compete),
    )
    .await;
    set_level_and_intention(
        &state,
        &igual,
        Sport::Tennis,
        SkillLevel::Intermediate,
        None,
    )
    .await;
    set_level_and_intention(&state, &mejor, Sport::Tennis, SkillLevel::Advanced, None).await;

    let found = discover::service::discover(&state, &yo, DiscoverFilters::for_sport(Sport::Tennis))
        .await
        .expect("discover");

    let pos = |id: &str| found.iter().position(|p| p.user_id == id);
    assert!(
        pos(&igual) < pos(&mejor),
        "compitiendo, alguien de tu nivel va antes"
    );

    cleanup(&state, &[&yo, &igual, &mejor]).await;
}

// --- Oferta quemada: el PASS caduca, el unmatch no entierra a nadie ---

/// Un PASS escondía a alguien para siempre. Con la densidad real de la app
/// (decenas de personas por ciudad, no miles) eso vacía el feed en dos
/// tardes y ya no se llena nunca más.
#[tokio::test]
async fn el_pass_caduca_y_esa_persona_vuelve_a_salir() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let otro = make_user(&state, c, "otro", &[Sport::Tennis]).await;

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

    let recien_pasado = discover::service::discover(&state, &yo, DiscoverFilters::default())
        .await
        .unwrap();
    assert!(
        !recien_pasado.iter().any(|p| p.user_id == otro),
        "un pase reciente tiene que seguir escondiendo"
    );

    age_swipe(
        &state,
        &yo,
        &otro,
        discover::service::PASS_EXPIRES_AFTER_DAYS + 1,
    )
    .await;

    let caducado = discover::service::discover(&state, &yo, DiscoverFilters::default())
        .await
        .unwrap();
    assert!(
        caducado.iter().any(|p| p.user_id == otro),
        "pasado el plazo, esa persona tiene que volver al feed"
    );

    cleanup(&state, &[&yo, &otro]).await;
}

/// El LIKE no caduca: o cerró un match (y entonces se habla por el chat) o
/// la otra persona todavía puede corresponderlo. Devolverlo al feed sería
/// dejar dar like dos veces a la misma persona.
#[tokio::test]
async fn el_like_no_caduca() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let otro = make_user(&state, c, "otro", &[Sport::Tennis]).await;

    swipes::service::create_swipe(&state, &yo, like(&otro, Sport::Tennis))
        .await
        .unwrap();
    age_swipe(
        &state,
        &yo,
        &otro,
        discover::service::PASS_EXPIRES_AFTER_DAYS * 10,
    )
    .await;

    let found = discover::service::discover(&state, &yo, DiscoverFilters::default())
        .await
        .unwrap();
    assert!(
        !found.iter().any(|p| p.user_id == otro),
        "a quien diste like no se le vuelve a enseñar, por viejo que sea"
    );

    cleanup(&state, &[&yo, &otro]).await;
}

/// Deshacer un match borraba el match pero dejaba los dos LIKE en pie, y un
/// LIKE esconde para siempre: las dos personas quedaban mutuamente
/// invisibles de por vida, incluida la que no deshizo nada.
#[tokio::test]
async fn deshacer_un_match_no_esconde_a_los_dos_para_siempre() {
    let state = test_state().await;
    let c = fresh_cluster();
    let uno = make_user(&state, c, "uno", &[Sport::Tennis]).await;
    let dos = make_user(&state, c, "dos", &[Sport::Tennis]).await;

    swipes::service::create_swipe(&state, &uno, like(&dos, Sport::Tennis))
        .await
        .unwrap();
    let res = swipes::service::create_swipe(&state, &dos, like(&uno, Sport::Tennis))
        .await
        .unwrap();
    let match_id = res.match_id.expect("el like reciproco hace match");

    matches::service::unmatch(&state, &match_id, &uno)
        .await
        .expect("unmatch");

    // Justo después no se ven: es lo que se pidió al deshacer el match.
    for (yo, otro) in [(&uno, &dos), (&dos, &uno)] {
        let found = discover::service::discover(&state, yo, DiscoverFilters::default())
            .await
            .unwrap();
        assert!(
            !found.iter().any(|p| &p.user_id == otro),
            "recien deshecho el match, no deben volver a verse todavia"
        );
    }

    // Pero el like caducó a PASS, así que un mes después vuelven al feed.
    age_swipe(
        &state,
        &uno,
        &dos,
        discover::service::PASS_EXPIRES_AFTER_DAYS + 1,
    )
    .await;
    age_swipe(
        &state,
        &dos,
        &uno,
        discover::service::PASS_EXPIRES_AFTER_DAYS + 1,
    )
    .await;

    for (yo, otro) in [(&uno, &dos), (&dos, &uno)] {
        let found = discover::service::discover(&state, yo, DiscoverFilters::default())
            .await
            .unwrap();
        assert!(
            found.iter().any(|p| &p.user_id == otro),
            "pasado el plazo se pueden volver a cruzar: un unmatch no es un bloqueo"
        );
    }

    cleanup(&state, &[&uno, &dos]).await;
}

// --- Disponibilidad: de dato decorativo a criterio de búsqueda ---

/// Bit del horario semanal: `día * 3 + franja`, lunes primero.
fn slot(day: i32, band: i32) -> i32 {
    1 << (day * 3 + band)
}

/// El filtro de "cuándo puedo jugar", que es la pregunta con la que ahora
/// arranca la pantalla de buscar.
#[tokio::test]
async fn discover_filtra_por_cuando_puede_jugar_cada_uno() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let sabado = make_user(&state, c, "sabado", &[Sport::Tennis]).await;
    let entresemana = make_user(&state, c, "entresemana", &[Sport::Tennis]).await;
    let sinhorario = make_user(&state, c, "sinhorario", &[Sport::Tennis]).await;

    set_availability(&state, &sabado, slot(5, 0)).await; // sábado mañana
    set_availability(&state, &entresemana, slot(1, 1)).await; // martes tarde
    set_availability(&state, &sinhorario, 0).await;

    let filtros = DiscoverFilters {
        sport: Some(Sport::Tennis),
        availability: Some(slot(5, 0)),
        ..DiscoverFilters::default()
    };
    let found = discover::service::discover(&state, &yo, filtros)
        .await
        .unwrap();
    let ids: Vec<&str> = found.iter().map(|p| p.user_id.as_str()).collect();

    assert!(
        ids.contains(&sabado.as_str()),
        "quien tiene ese hueco marcado tiene que salir"
    );
    assert!(
        !ids.contains(&entresemana.as_str()),
        "quien no tiene ese hueco no sale"
    );
    assert!(
        !ids.contains(&sinhorario.as_str()),
        "quien no ha rellenado el horario tampoco: la pregunta era cuando puede"
    );

    cleanup(&state, &[&yo, &sabado, &entresemana, &sinhorario]).await;
}

/// Una máscara vacía no puede significar "nadie": es lo que llega cuando el
/// usuario no ha tocado el filtro todavía.
#[tokio::test]
async fn una_mascara_vacia_no_filtra_nada() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let otro = make_user(&state, c, "otro", &[Sport::Tennis]).await;

    let filtros = DiscoverFilters {
        sport: Some(Sport::Tennis),
        availability: Some(0),
        ..DiscoverFilters::default()
    };
    let found = discover::service::discover(&state, &yo, filtros)
        .await
        .unwrap();
    assert!(
        found.iter().any(|p| p.user_id == otro),
        "sin huecos elegidos el feed no puede salir vacio"
    );

    cleanup(&state, &[&yo, &otro]).await;
}

/// El corazón del cambio de producto: con todo lo demás igual, sale antes
/// quien coincide contigo en el horario que quien está más cerca.
#[tokio::test]
async fn coincidir_en_horario_pesa_mas_que_la_distancia() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    // Un poco más lejos que el otro, pero coincide en dos huecos.
    let coincide = make_user(&state, (c.0 + 0.02, c.1), "coincide", &[Sport::Tennis]).await;
    let cerca = make_user(&state, c, "cerca", &[Sport::Tennis]).await;

    let mi_horario = slot(5, 0) | slot(6, 0); // fin de semana por la mañana
    set_availability(&state, &yo, mi_horario).await;
    set_availability(&state, &coincide, mi_horario).await;
    set_availability(&state, &cerca, slot(2, 2)).await; // miércoles noche

    let found = discover::service::discover(&state, &yo, DiscoverFilters::for_sport(Sport::Tennis))
        .await
        .unwrap();
    let ids: Vec<&str> = found.iter().map(|p| p.user_id.as_str()).collect();
    let pos_coincide = ids.iter().position(|id| *id == coincide).expect("coincide");
    let pos_cerca = ids.iter().position(|id| *id == cerca).expect("cerca");

    assert!(
        pos_coincide < pos_cerca,
        "con quien puedes quedar de verdad va antes que quien pilla mas cerca: {ids:?}"
    );

    let suyo = found.iter().find(|p| p.user_id == coincide).unwrap();
    assert_eq!(
        suyo.shared_slots, 2,
        "los huecos en comun se mandan calculados, que es lo que la lista ensena"
    );

    cleanup(&state, &[&yo, &coincide, &cerca]).await;
}

/// `shared_availability`/`shared_slots` son relativos a quien mira, como
/// `distanceKm` o `likesYou`: no pueden salir por el perfil público.
#[tokio::test]
async fn el_horario_en_comun_no_sale_del_perfil_publico() {
    let state = test_state().await;
    let c = fresh_cluster();
    let yo = make_user(&state, c, "yo", &[Sport::Tennis]).await;
    let otro = make_user(&state, c, "otro", &[Sport::Tennis]).await;
    set_availability(&state, &yo, slot(5, 0)).await;
    set_availability(&state, &otro, slot(5, 0)).await;

    let publico = matchpoint_api::users::service::get_profile(&state, &otro)
        .await
        .expect("perfil publico");

    assert_eq!(publico.shared_slots, 0);
    assert_eq!(publico.shared_availability, 0);

    cleanup(&state, &[&yo, &otro]).await;
}
