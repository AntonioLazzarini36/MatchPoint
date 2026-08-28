//! Andamiaje compartido por los tests de integración.
//!
//! Estos tests hablan con **una base de datos de verdad**, no con mocks. Las
//! reglas que prueban (cuándo salta un match, quién puede aceptar una
//! propuesta, a quién enseña Discover) viven en consultas SQL con joins,
//! filtros y `NOT IN`: un mock del acceso a datos comprobaría que la función
//! llama a lo que espera el propio test, no que la regla se cumple. Y las dos
//! veces que estas reglas se rompieron de verdad fue justamente en la
//! consulta.
//!
//! Necesitan `DATABASE_URL`. CI levanta un Postgres y la define; en local hace
//! falta la base de desarrollo levantada (ver CLAUDE.md).

use std::sync::Arc;

use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use matchpoint_api::auth::rate_limit::RateLimiter;
use matchpoint_api::config::AppConfig;
use matchpoint_api::mail::Mailer;
use matchpoint_api::models::{
    Intention, NewProfile, NewUser, NewUserSkillLevel, SkillLevel, Sport,
};
use matchpoint_api::push::Pusher;
use matchpoint_api::schema::{profiles, proposals, skill_levels, swipes, users};
use matchpoint_api::state::AppState;

/// Variables que `AppConfig::from_env` exige. Se ponen aquí para que los
/// tests no dependan de que quien los ejecute tenga un `.env` completo.
fn ensure_env() {
    let defaults = [
        ("JWT_ACCESS_SECRET", "test_access_secret_para_tests"),
        ("JWT_REFRESH_SECRET", "test_refresh_secret_para_tests"),
        (
            "MESSAGE_KEY_BASE64",
            "1mKQdNgaRWyt/45tyC5TKw9ogvCE45Kq5p+wciokGtg=",
        ),
    ];
    for (key, value) in defaults {
        if std::env::var(key).is_err() {
            // SAFETY: los tests de un mismo binario corren en hilos, pero
            // esto ocurre antes de que ninguno lea la config y siempre
            // escribe el mismo valor.
            unsafe { std::env::set_var(key, value) };
        }
    }
}

pub async fn test_state() -> AppState {
    ensure_env();
    let config = AppConfig::from_env();
    let db = matchpoint_api::db::build_pool(&config.database_url).await;

    AppState {
        db,
        config: Arc::new(config),
        rate_limiter: RateLimiter::new(),
        mailer: Mailer::Log,
        // Sin credenciales: las notificaciones que disparen estos tests van
        // al log, no a ningún móvil.
        pusher: Pusher::Log,
    }
}

/// Un punto del mapa lejos de cualquier dato sembrado, distinto en cada
/// llamada.
///
/// Los tests de Discover comparan **orden**, y el feed se corta a 20
/// resultados: en una base con perfiles de desarrollo dentro, los usuarios
/// del test se caen fuera de esa ventana y el test falla por un motivo que no
/// tiene nada que ver con lo que comprueba. Dándole a cada test su propio
/// rincón del planeta, el filtro de distancia se encarga de que sólo se vean
/// entre ellos — que es justo el aislamiento que hace falta.
pub fn fresh_cluster() -> (f64, f64) {
    // Uuid v4 viene del CSPRNG del sistema: sirve de fuente de aleatoriedad
    // sin añadir la crate `rand` sólo para esto.
    let seed = uuid::Uuid::new_v4().as_u128();
    let lat = 55.0 + ((seed % 20_000) as f64) / 1000.0;
    let lng = 20.0 + (((seed >> 64) % 20_000) as f64) / 1000.0;
    (lat, lng)
}

/// Crea un usuario con perfil listo para aparecer en Discover.
///
/// El sufijo aleatorio en el email es lo que permite correr los tests en
/// paralelo (que es como los corre Rust por defecto) sin que unos pisen las
/// cuentas de otros.
pub async fn make_user(
    state: &AppState,
    cluster: (f64, f64),
    tag: &str,
    sports: &[Sport],
) -> String {
    let id = uuid::Uuid::new_v4().to_string();
    let email = format!("it-{tag}-{id}@test.local");
    let mut conn = state.db.get().await.expect("pool");

    diesel::insert_into(users::table)
        .values(NewUser {
            id: id.clone(),
            email: &email,
            password_hash: "x".to_string(),
            updated_at: chrono::Utc::now(),
        })
        .execute(&mut conn)
        .await
        .expect("insert user");

    diesel::insert_into(profiles::table)
        .values(NewProfile {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: id.clone(),
            display_name: tag.to_string(),
            birth_date: "1995-01-01T00:00:00Z".parse().expect("fecha"),
            gender: None,
            intention: None,
            city: Some("Malaga".to_string()),
            bio: None,
            // Discover exige al menos una foto y coordenadas: sin esto los
            // tests de Discover no verían a nadie y pareceria un fallo del
            // filtro.
            photos: vec!["https://example.test/foto.png".to_string()],
            sports: sports.to_vec(),
            // Horario semanal vacio: ya no entra en la ordenacion, asi que
            // no afecta a lo que estos tests comprueban.
            availability: 0,
            latitude: Some(cluster.0),
            longitude: Some(cluster.1),
            years_playing: None,
            club: None,
            achievements: vec![],
            avg_pace_min_per_km: None,
            avg_distance_km: None,
            updated_at: chrono::Utc::now(),
        })
        .execute(&mut conn)
        .await
        .expect("insert profile");

    id
}

/// Borra las cuentas creadas por un test. Todo lo demás (perfiles, swipes,
/// matches, propuestas) cae por `ON DELETE CASCADE`.
pub async fn cleanup(state: &AppState, ids: &[&str]) {
    let mut conn = state.db.get().await.expect("pool");
    diesel::delete(users::table.filter(users::id.eq_any(ids)))
        .execute(&mut conn)
        .await
        .expect("cleanup");
}

/// Fija el nivel de alguien en un deporte y a qué viene. Los tests de orden
/// de Discover lo necesitan: sin nivel no hay nada que comparar.
pub async fn set_level_and_intention(
    state: &AppState,
    user_id: &str,
    sport: Sport,
    level: SkillLevel,
    intention: Option<Intention>,
) {
    let mut conn = state.db.get().await.expect("pool");

    diesel::insert_into(skill_levels::table)
        .values(NewUserSkillLevel {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            sport,
            level,
            updated_at: chrono::Utc::now(),
        })
        .on_conflict((skill_levels::user_id, skill_levels::sport))
        .do_update()
        .set(skill_levels::level.eq(level))
        .execute(&mut conn)
        .await
        .expect("skill level");

    diesel::update(profiles::table.filter(profiles::user_id.eq(user_id)))
        .set(profiles::intention.eq(intention))
        .execute(&mut conn)
        .await
        .expect("intention");
}

/// Fija el horario semanal habitual de alguien (`Profile.availability`),
/// como el mapa de bits de 21 posiciones que usa el resto de la app:
/// `bit = día * 3 + franja`, lunes primero, franjas mañana/tarde/noche.
pub async fn set_availability(state: &AppState, user_id: &str, mask: i32) {
    let mut conn = state.db.get().await.expect("pool");
    diesel::update(profiles::table.filter(profiles::user_id.eq(user_id)))
        .set(profiles::availability.eq(mask))
        .execute(&mut conn)
        .await
        .expect("availability");
}

/// Envejece un swipe ya hecho, para poder comprobar la caducidad del PASS
/// sin esperar un mes. Es la única forma de probarlo: el plazo lo mide el
/// servicio contra `Utc::now()`.
pub async fn age_swipe(state: &AppState, from: &str, to: &str, days: i64) {
    let mut conn = state.db.get().await.expect("pool");
    diesel::update(
        swipes::table
            .filter(swipes::from_user_id.eq(from))
            .filter(swipes::to_user_id.eq(to)),
    )
    .set(swipes::created_at.eq(chrono::Utc::now() - chrono::Duration::days(days)))
    .execute(&mut conn)
    .await
    .expect("age swipe");
}

/// Mueve una propuesta al pasado, para poder probar el historial sin esperar.
pub async fn age_proposal(state: &AppState, proposal_id: &str, hours_ago: i64) {
    let mut conn = state.db.get().await.expect("pool");
    diesel::update(proposals::table.filter(proposals::id.eq(proposal_id)))
        .set(proposals::scheduled_at.eq(chrono::Utc::now() - chrono::Duration::hours(hours_ago)))
        .execute(&mut conn)
        .await
        .expect("age proposal");
}
