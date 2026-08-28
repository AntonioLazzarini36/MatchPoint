//! Test data generator. Run with `cargo run --bin datagen`.
//!
//! Seeds ~10 varied fake profiles (User + Profile + Preferences + photos)
//! so you don't have to register accounts by hand to test
//! discover/swipes/matches. Idempotent: skips any email that already
//! exists, so it's safe to re-run — but it *does* backfill photos on a
//! profile that has none, so re-running repairs seed data that predates
//! generated photos.
//!
//! Photos are drawn locally (see `mod photo`) rather than downloaded:
//! `/discover` now requires at least one photo, so seed profiles without
//! one would simply not exist as far as the app is concerned.
//!
//! Usage:
//!   cargo run --bin datagen
//!       -> seeds the 10 fake profiles (skips ones that already exist)
//!
//!   cargo run --bin datagen -- --me you@example.com yourpassword "Your Name" "Málaga"
//!       -> seeds (or skips if it already exists) just your own profile,
//!          does NOT touch the fake ones.
//!
//! All fake accounts share the password below so you can log in as any of
//! them from the Flutter app while testing.

use chrono::{DateTime, NaiveDate, Utc};
use diesel::prelude::*;
use diesel::result::OptionalExtension;
use diesel_async::scoped_futures::ScopedFutureExt;
use diesel_async::RunQueryDsl;
use diesel_async::{AsyncConnection, AsyncPgConnection};

use matchpoint_api::config::AppConfig;
use matchpoint_api::db;
use matchpoint_api::models::{
    Gender, Intention, NewPreferences, NewProfile, NewUser, NewUserSkillLevel, SkillLevel, Sport,
};
use matchpoint_api::schema::{preferences, profiles, skill_levels, users};

use std::path::Path;

const FAKE_PASSWORD: &str = "password123";

struct FakeProfile {
    email: &'static str,
    display_name: &'static str,
    birth_date: &'static str, // "YYYY-MM-DD"
    city: &'static str,
    // Real Costa del Sol coordinates for `city`, so the /discover distance
    // filter has something meaningful to test against — these towns are
    // all within ~20-30km of each other, close to the default radius.
    latitude: f64,
    longitude: f64,
    bio: &'static str,
    sports: &'static [Sport],
    sports_wanted: &'static [Sport],
    // Seeded for real (not None) so /discover's gender filter has data to
    // actually filter against when testing it.
    gender: Option<Gender>,
    // A que viene. Se siembran las cuatro para que Discovery tenga variedad
    // real al probar, en vez de diez perfiles diciendo lo mismo.
    intention: Option<Intention>,
    // Se siembran franjas variadas para que el orden de Discover por
    // coincidencia horaria tenga algo real que ordenar al probarlo.
    availability: i32,
    gender_preference: Option<Gender>,
    // Experiencia: lo que se enseña en el perfil para que otra persona
    // pueda juzgar si juega a su nivel.
    years_playing: Option<i32>,
    club: Option<&'static str>,
    // Ritmo y distancia media son de correr. Se quedan en el modelo porque
    // la columna sigue existiendo (running está apagado, no borrado — ver
    // `app_sports.dart`), pero **ningún perfil sembrado los usa**: la app es
    // de tenis y un perfil de prueba que hable de rodajes es justo lo que no
    // se quiere enseñar.
    avg_pace_min_per_km: Option<f64>,
    avg_distance_km: Option<f64>,
    achievements: &'static [&'static str],
    // One level per entry in `sports`, same order — kept as a parallel
    // list here only because it's static seed data typed by hand; the
    // real DB rows are a proper (user, sport) table, see models.rs.
    skill_levels: &'static [SkillLevel],
}

/// Un hueco del horario semanal como bit suelto.
///
/// `dia`: 0 = lunes ... 6 = domingo. `franja`: 0 = mañana, 1 = tarde,
/// 2 = noche. Ver `models::Profile::availability`.
const fn slot(dia: i32, franja: i32) -> i32 {
    1 << (dia * 3 + franja)
}

/// Horarios de ejemplo con pinta de real, y **distintos entre sí**.
///
/// Que sean distintos es el punto: desde que el feed ordena y filtra por
/// "cuándo podéis los dos", sembrar a los diez perfiles con el mismo horario
/// deja la pantalla diciendo lo mismo en todas las filas — que es exactamente
/// como se vería si la funcionalidad no estuviera hecha.
const WEEK_EVENINGS: i32 = slot(0, 2) | slot(1, 1) | slot(2, 2) | slot(3, 1) | slot(5, 0);
const WEEKENDS: i32 = slot(5, 0) | slot(5, 1) | slot(6, 0) | slot(6, 1);
const EARLY_BIRD: i32 = slot(0, 0) | slot(1, 0) | slot(2, 0) | slot(3, 0) | slot(4, 0) | slot(5, 0);
const AFTER_WORK: i32 = slot(1, 2) | slot(3, 2) | slot(4, 2) | slot(5, 2);
const MIDWEEK_AFTERNOONS: i32 = slot(1, 1) | slot(2, 1) | slot(3, 1);
const ALMOST_ALWAYS: i32 = WEEK_EVENINGS | WEEKENDS | MIDWEEK_AFTERNOONS;

const FAKE_PROFILES: &[FakeProfile] = &[
    FakeProfile {
        email: "lucia.tenis@example.com",
        display_name: "Lucía",
        birth_date: "1996-04-12",
        city: "Málaga",
        latitude: 36.7213,
        longitude: -4.4214,
        bio: "Tenis los fines de semana, nivel intermedio. Busco rival constante.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender: Some(Gender::Female),
        intention: Some(Intention::Compete),
        availability: WEEK_EVENINGS,
        gender_preference: None,
        years_playing: Some(5),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Intermediate],
    },
    FakeProfile {
        email: "marcos.tenis@example.com",
        display_name: "Marcos",
        birth_date: "1993-09-02",
        city: "Benalmádena",
        latitude: 36.5988,
        longitude: -4.5163,
        bio: "Juego dos o tres tardes por semana. Fondo de pista y mucha paciencia.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Male),
        intention: Some(Intention::Train),
        availability: WEEKENDS,
        gender_preference: None,
        years_playing: Some(7),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Intermediate],
    },
    FakeProfile {
        email: "sofia.tenis@example.com",
        display_name: "Sofía",
        birth_date: "1999-01-20",
        city: "Málaga",
        latitude: 36.7213,
        longitude: -4.4214,
        bio: "Empecé hace poco y voy a clase los martes. Busco partidos tranquilos para coger ritmo.",
        sports: &[Sport::Tennis, Sport::Running],
        sports_wanted: &[Sport::Tennis, Sport::Running],
        gender: Some(Gender::Female),
        intention: Some(Intention::Learn),
        availability: EARLY_BIRD,
        gender_preference: None,
        years_playing: Some(1),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Beginner, SkillLevel::Beginner],
    },
    FakeProfile {
        email: "javier.club@example.com",
        display_name: "Javier",
        birth_date: "1990-11-05",
        city: "Torremolinos",
        latitude: 36.6203,
        longitude: -4.4998,
        bio: "Juego en el club desde hace años. Nivel avanzado, busco reto.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender: Some(Gender::Male),
        intention: Some(Intention::Fun),
        availability: AFTER_WORK,
        gender_preference: None,
        years_playing: Some(12),
        club: Some("Club de Tenis Torremolinos"),
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Advanced],
    },
    FakeProfile {
        email: "elena.tenis@example.com",
        display_name: "Elena",
        birth_date: "1988-06-30",
        city: "Fuengirola",
        latitude: 36.5411,
        longitude: -4.6247,
        bio: "Vuelvo después de dos años parada. Nivel medio, ganas de reengancharme.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Female),
        intention: Some(Intention::Compete),
        availability: MIDWEEK_AFTERNOONS,
        gender_preference: None,
        years_playing: Some(9),
        club: Some("Club de Tenis Capellanía"),
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Intermediate],
    },
    FakeProfile {
        email: "pablo.finde@example.com",
        display_name: "Pablo",
        birth_date: "2001-03-15",
        city: "Málaga",
        latitude: 36.7213,
        longitude: -4.4214,
        bio: "Tenis casual los sábados por la mañana, sin presión.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender: Some(Gender::Male),
        intention: Some(Intention::Train),
        availability: WEEKENDS,
        gender_preference: None,
        years_playing: Some(1),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Beginner],
    },
    FakeProfile {
        email: "carla.tenis@example.com",
        display_name: "Carla",
        birth_date: "1995-08-22",
        city: "Mijas",
        latitude: 36.5959,
        longitude: -4.6372,
        bio: "Prefiero dobles, pero juego individuales si hace falta. Sin dramas por el marcador.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Female),
        intention: Some(Intention::Learn),
        availability: ALMOST_ALWAYS,
        gender_preference: None,
        years_playing: Some(4),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Intermediate],
    },
    FakeProfile {
        email: "diego.competitivo@example.com",
        display_name: "Diego",
        birth_date: "1992-12-01",
        city: "Málaga",
        latitude: 36.7213,
        longitude: -4.4214,
        bio: "Compito en torneos locales. Busco sparring de nivel alto.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender: Some(Gender::Male),
        intention: Some(Intention::Fun),
        availability: WEEK_EVENINGS,
        gender_preference: None,
        years_playing: Some(15),
        club: Some("Club de Tenis Málaga"),
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[
            "Campeón provincial +35, 2024",
            "Semifinalista Copa Andalucía 2023",
        ],
        skill_levels: &[SkillLevel::Competitive],
    },
    FakeProfile {
        email: "andrea.principiante@example.com",
        display_name: "Andrea",
        birth_date: "1998-05-18",
        city: "Benalmádena",
        latitude: 36.5988,
        longitude: -4.5163,
        bio: "Empezando en esto del tenis, busco gente paciente. Voy los sábados por la mañana.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Female),
        intention: Some(Intention::Compete),
        availability: EARLY_BIRD,
        gender_preference: None,
        years_playing: Some(1),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Beginner],
    },
    FakeProfile {
        email: "hugo.tenis@example.com",
        display_name: "Hugo",
        birth_date: "1994-02-27",
        city: "Torremolinos",
        latitude: 36.6203,
        longitude: -4.4998,
        bio: "Juego desde el instituto. Nivel intermedio tirando a alto, disponible casi cualquier tarde.",
        sports: &[Sport::Tennis, Sport::Running],
        sports_wanted: &[Sport::Tennis, Sport::Running],
        gender: Some(Gender::Male),
        intention: Some(Intention::Train),
        availability: AFTER_WORK,
        gender_preference: None,
        years_playing: Some(12),
        club: Some("Club de Tenis Benalmádena"),
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &["Campeón del torneo social de su club (2024)"],
        skill_levels: &[SkillLevel::Intermediate, SkillLevel::Intermediate],
    },
];

fn parse_birth_date(s: &str) -> DateTime<Utc> {
    NaiveDate::parse_from_str(s, "%Y-%m-%d")
        .expect("invalid birth date in seed data")
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_utc()
}

/// Shared insert logic: User + Profile + Preferences in one transaction,
/// same shape as auth::service::register. Returns `true` if it inserted,
/// `false` if the email already existed and was skipped.
#[allow(clippy::too_many_arguments)]
async fn seed_one(
    conn: &mut AsyncPgConnection,
    email: &str,
    password: &str,
    display_name: &str,
    birth_date: DateTime<Utc>,
    city: Option<&str>,
    location: Option<(f64, f64)>,
    bio: Option<&str>,
    sports: Vec<Sport>,
    sports_wanted: Vec<Sport>,
    gender: Option<Gender>,
    // A que viene. Se siembran las cuatro para que Discovery tenga variedad
    // real al probar, en vez de diez perfiles diciendo lo mismo.
    intention: Option<Intention>,
    // Se siembran franjas variadas para que el orden de Discover por
    // coincidencia horaria tenga algo real que ordenar al probarlo.
    availability: i32,
    gender_preference: Option<Gender>,
    years_playing: Option<i32>,
    club: Option<&str>,
    avg_pace_min_per_km: Option<f64>,
    avg_distance_km: Option<f64>,
    achievements: Vec<String>,
    skill_levels_by_sport: Vec<(Sport, SkillLevel)>,
    photos: Vec<String>,
) -> anyhow::Result<bool> {
    let existing = users::table
        .filter(users::email.eq(email))
        .select(users::id)
        .first::<String>(conn)
        .await
        .optional()?;

    if existing.is_some() {
        return Ok(false);
    }

    let password_hash =
        bcrypt::hash(password, bcrypt::DEFAULT_COST).expect("bcrypt should not fail");
    let user_id = uuid::Uuid::new_v4().to_string();

    let tx_user_id = user_id.clone();
    let tx_email = email.to_string();
    let tx_display_name = display_name.to_string();
    let tx_city = city.map(|c| c.to_string());
    let tx_bio = bio.map(|b| b.to_string());
    let tx_club = club.map(|c| c.to_string());
    let tx_photos = photos;

    conn.transaction::<_, anyhow::Error, _>(|conn| {
        async move {
            diesel::insert_into(users::table)
                .values(NewUser {
                    id: tx_user_id.clone(),
                    email: &tx_email,
                    password_hash,
                    updated_at: Utc::now(),
                })
                .execute(conn)
                .await?;

            diesel::insert_into(profiles::table)
                .values(NewProfile {
                    id: uuid::Uuid::new_v4().to_string(),
                    user_id: tx_user_id.clone(),
                    display_name: tx_display_name,
                    birth_date,
                    gender,
                    intention,
                    availability,
                    city: tx_city,
                    bio: tx_bio,
                    photos: tx_photos,
                    sports,
                    latitude: location.map(|(lat, _)| lat),
                    longitude: location.map(|(_, lng)| lng),
                    years_playing,
                    club: tx_club,
                    achievements,
                    avg_pace_min_per_km,
                    avg_distance_km,
                    updated_at: Utc::now(),
                })
                .execute(conn)
                .await?;

            diesel::insert_into(preferences::table)
                .values(NewPreferences {
                    id: uuid::Uuid::new_v4().to_string(),
                    user_id: tx_user_id.clone(),
                    sports_wanted,
                    distance_km: 25,
                    age_min: 18,
                    age_max: 60,
                    gender_preference,
                    updated_at: Utc::now(),
                })
                .execute(conn)
                .await?;

            for (sport, level) in skill_levels_by_sport {
                diesel::insert_into(skill_levels::table)
                    .values(NewUserSkillLevel {
                        id: uuid::Uuid::new_v4().to_string(),
                        user_id: tx_user_id.clone(),
                        sport,
                        level,
                        updated_at: Utc::now(),
                    })
                    .execute(conn)
                    .await?;
            }

            Ok(())
        }
        .scope_boxed()
    })
    .await?;

    Ok(true)
}

/// Donde viven los avatares que usa la app.
///
/// Ruta relativa a `services/api-rust/`, que es desde donde se ejecuta
/// datagen. **No se usa `include_bytes!`** aunque sería más robusto: el
/// macro resolvería en tiempo de compilacion, y el contexto de build del
/// `Dockerfile` es `services/api-rust`, asi que una ruta que sale de ahi
/// rompe la imagen — y con ella el job `docker` de CI. Leerlos en tiempo de
/// ejecucion mantiene el crate compilable en cualquier contexto, a cambio de
/// que si no estan se caiga al dibujo generado (ver abajo).
const AVATAR_DIR: &str = "../../apps/mobile/assets/avatars";
const AVATAR_COUNT: u32 = 6;

/// Escribe (si no existe ya) las fotos de un perfil sembrado y devuelve sus
/// URLs publicas, en el mismo formato que las que sube la app
/// (`{public_base_url}/uploads/{archivo}`).
///
/// **Usa los mismos avatares que ofrece la app** en vez del dibujo generado
/// de una pista en perspectiva. El dibujo cumplia su funcion —que los
/// perfiles sembrados salieran en Discover, que exige foto— pero enseñar la
/// app con diez tarjetas de una pista naranja vacia se ve exactamente como
/// lo que es: relleno. Los avatares son personas dibujadas, que es lo que va
/// en ese hueco, y ademas son los mismos que se le ofrecen a quien se
/// registra, asi que la pantalla se ve coherente.
///
/// Si los avatares no estan donde se esperan (otro directorio de trabajo, un
/// clon parcial) se cae al dibujo generado: es preferible un perfil feo a un
/// perfil sin foto, que directamente no aparece.
///
/// El nombre del archivo se deriva del email, asi que re-sembrar no duplica
/// archivos ni cambia las fotos de nadie.
fn ensure_photos(cfg: &AppConfig, email: &str, sport: Sport, count: u32) -> Vec<String> {
    let dir = Path::new(&cfg.photos_dir);
    if let Err(e) = std::fs::create_dir_all(dir) {
        eprintln!("  ! no se pudo crear {}: {e}", cfg.photos_dir);
        return vec![];
    }

    let slug: String = email
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect();

    // Reparto estable por email: el mismo perfil se queda siempre con el
    // mismo avatar entre ejecuciones, y dos perfiles seguidos no repiten.
    let seed = email.bytes().map(|b| b as u32).sum::<u32>();

    let mut urls = Vec::new();
    for variant in 0..count {
        let avatar_index = (seed + variant) % AVATAR_COUNT + 1;
        let source = Path::new(AVATAR_DIR).join(format!("character{avatar_index}.jpg"));

        let (bytes, ext) = match std::fs::read(&source) {
            Ok(bytes) => (bytes, "jpg"),
            Err(_) => (photo::render(email, sport, variant), "png"),
        };

        let filename = format!("seed-{slug}-{variant}.{ext}");
        let path = dir.join(&filename);
        if !path.exists() {
            if let Err(e) = std::fs::write(&path, &bytes) {
                eprintln!("  ! no se pudo escribir {}: {e}", path.display());
                continue;
            }
        }
        urls.push(format!("{}/uploads/{}", cfg.public_base_url, filename));
    }
    urls
}

/// Rellena las fotos de un perfil ya sembrado que se quedo sin ellas.
///
/// Los perfiles falsos existian desde antes de que hubiera fotos
/// generadas, y `seed_one` se salta los emails ya creados — sin esto,
/// volver a ejecutar datagen no arreglaba una base de datos ya sembrada y
/// los 10 perfiles seguian invisibles en Discover.
async fn backfill_photos(
    conn: &mut AsyncPgConnection,
    email: &str,
    photos: &[String],
) -> anyhow::Result<bool> {
    if photos.is_empty() {
        return Ok(false);
    }

    let existing = users::table
        .inner_join(profiles::table.on(profiles::user_id.eq(users::id)))
        .filter(users::email.eq(email))
        .select((users::id, profiles::photos))
        .first::<(String, Vec<String>)>(conn)
        .await
        .optional()?;

    let Some((user_id, current)) = existing else {
        return Ok(false);
    };
    if !current.is_empty() {
        return Ok(false);
    }

    diesel::update(profiles::table.filter(profiles::user_id.eq(user_id)))
        .set((
            profiles::photos.eq(photos.to_vec()),
            profiles::updated_at.eq(Utc::now()),
        ))
        .execute(conn)
        .await?;

    Ok(true)
}

async fn seed_fakes(conn: &mut AsyncPgConnection, cfg: &AppConfig) -> anyhow::Result<()> {
    println!("Seeding {} fake profiles...\n", FAKE_PROFILES.len());

    let mut created = 0;
    let mut skipped = 0;
    let mut repaired = 0;

    for p in FAKE_PROFILES {
        let skill_levels_by_sport: Vec<(Sport, SkillLevel)> = p
            .sports
            .iter()
            .copied()
            .zip(p.skill_levels.iter().copied())
            .collect();

        // Dos fotos por perfil: con una sola no se aprecia que el perfil
        // las apila en vertical, que es como se muestran ahora.
        let photos = ensure_photos(cfg, p.email, p.sports[0], 2);

        let inserted = seed_one(
            conn,
            p.email,
            FAKE_PASSWORD,
            p.display_name,
            parse_birth_date(p.birth_date),
            Some(p.city),
            Some((p.latitude, p.longitude)),
            Some(p.bio),
            p.sports.to_vec(),
            p.sports_wanted.to_vec(),
            p.gender,
            p.intention,
            p.availability,
            p.gender_preference,
            p.years_playing,
            p.club,
            p.avg_pace_min_per_km,
            p.avg_distance_km,
            p.achievements.iter().map(|s| s.to_string()).collect(),
            skill_levels_by_sport,
            photos.clone(),
        )
        .await?;

        if inserted {
            println!("  + creado   {} ({})", p.email, p.display_name);
            created += 1;
        } else if backfill_photos(conn, p.email, &photos).await? {
            println!("  ~ fotos puestas a {} (ya existía sin ellas)", p.email);
            repaired += 1;
        } else {
            println!("  - ya existe {}", p.email);
            skipped += 1;
        }
    }

    println!("\nListo: {created} creados, {repaired} reparados, {skipped} ya existían.");
    if created > 0 {
        println!("Contraseña de todos los perfiles falsos: {FAKE_PASSWORD}");
    }

    Ok(())
}

async fn seed_me(
    conn: &mut AsyncPgConnection,
    email: &str,
    password: &str,
    display_name: &str,
    city: Option<&str>,
) -> anyhow::Result<()> {
    let inserted = seed_one(
        conn,
        email,
        password,
        display_name,
        parse_birth_date("2000-01-01"),
        city,
        None, // sin coordenadas — ponlas luego desde la app
        None,
        vec![Sport::Tennis, Sport::Running],
        vec![Sport::Tennis, Sport::Running],
        None, // gender — se elige luego desde la app
        None, // intention — se elige luego desde la app
        0,    // availability — se elige luego desde la app
        None, // gender_preference
        None, // years_playing — se completa luego desde la app
        None,
        None,
        None,
        vec![],
        vec![],
        // Sin fotos: las suyas las sube el propio usuario desde la app.
        // Ojo: hasta que lo haga, `/discover` no lo mostrara a nadie.
        vec![],
    )
    .await?;

    if inserted {
        println!("Perfil propio creado: {email}");
        // Aviso, no comentario en el codigo: quien corre el comando no lee
        // el fuente, y una cuenta invisible sin motivo aparente es de las
        // cosas que cuesta mas rato entender.
        println!(
            "  Ojo: sin fotos ni ubicacion, /discover no te muestra a nadie mas.
               Completa las dos cosas desde la app antes de probar Discovery."
        );
    } else {
        println!("Ya existía un usuario con {email}, no se ha tocado nada.");
    }

    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().collect();

    // `--api` siembra una instalacion **remota** por su API publica en vez de
    // por su base de datos, y por un motivo concreto: **las fotos**. Escribir
    // en Postgres directo se puede hacer contra cualquier base, pero los
    // ficheros los escribe quien ejecuta el comando, asi que las filas
    // acabarian apuntando a `https://.../uploads/seed-....jpg` con esos
    // ficheros en un portatil y no en el volumen del servidor: diez tarjetas
    // con el hueco gris. Por la API cada perfil se crea como lo crearia una
    // persona, asi que la foto sube por el mismo sitio que las de verdad.
    if args.len() > 2 && args[1] == "--api" {
        return remote::seed_all(args[2].trim_end_matches('/')).await;
    }

    let cfg = AppConfig::from_env();
    let pool = db::build_pool(&cfg.database_url).await;
    let mut conn = pool.get().await.expect("failed to get a DB connection");

    if args.len() > 1 && args[1] == "--me" {
        // cargo run --bin datagen -- --me email password "Display Name" "City"
        let email = args
            .get(2)
            .expect("uso: --me <email> <password> [displayName] [city]");
        let password = args
            .get(3)
            .expect("uso: --me <email> <password> [displayName] [city]");
        let display_name = args.get(4).map(String::as_str).unwrap_or("Yo");
        let city = args.get(5).map(String::as_str);

        seed_me(&mut conn, email, password, display_name, city).await?;
    } else {
        seed_fakes(&mut conn, &cfg).await?;
    }

    Ok(())
}

/// Genera las fotos de los perfiles de prueba.
///
/// Los 10 perfiles falsos se sembraban con `photos: vec![]`, y Discover
/// ahora exige al menos una foto (un perfil sin foto no es un perfil), asi
/// que sin esto los datos de prueba desaparecian del feed entero.
///
/// Se dibujan aqui en vez de descargarlas de algun sitio: no depende de la
/// red ni de que un servicio de placeholders siga existiendo, es
/// determinista (la misma semilla da la misma imagen, asi que re-sembrar
/// no cambia las fotos) y deja claro que son datos de prueba sin fingir
/// ser una persona real.
mod photo {
    use matchpoint_api::models::Sport;

    pub const WIDTH: u32 = 1280;
    /// 16:9, la proporcion en la que la app guarda y muestra todo (ver
    /// `landscape_crop.dart` en el movil).
    pub const HEIGHT: u32 = 720;

    /// RGB de 0-255. Alias para que los pares de colores del degradado no
    /// disparen `clippy::type_complexity`.
    type Rgb = (u8, u8, u8);

    struct Canvas {
        pixels: Vec<u8>, // RGB
    }

    impl Canvas {
        fn new() -> Self {
            Canvas {
                pixels: vec![0; (WIDTH * HEIGHT * 3) as usize],
            }
        }

        fn set(&mut self, x: i32, y: i32, color: Rgb) {
            if x < 0 || y < 0 || x >= WIDTH as i32 || y >= HEIGHT as i32 {
                return;
            }
            let idx = ((y as u32 * WIDTH + x as u32) * 3) as usize;
            self.pixels[idx] = color.0;
            self.pixels[idx + 1] = color.1;
            self.pixels[idx + 2] = color.2;
        }

        fn get(&self, x: i32, y: i32) -> Rgb {
            let idx = ((y as u32 * WIDTH + x as u32) * 3) as usize;
            (self.pixels[idx], self.pixels[idx + 1], self.pixels[idx + 2])
        }

        /// Mezcla sobre lo que ya hay, para poder pintar lineas y sombras
        /// semitransparentes sin guardar canal alfa.
        fn blend(&mut self, x: i32, y: i32, color: Rgb, alpha: f64) {
            if x < 0 || y < 0 || x >= WIDTH as i32 || y >= HEIGHT as i32 {
                return;
            }
            let under = self.get(x, y);
            let mix = |a: u8, b: u8| (a as f64 * (1.0 - alpha) + b as f64 * alpha) as u8;
            self.set(
                x,
                y,
                (
                    mix(under.0, color.0),
                    mix(under.1, color.1),
                    mix(under.2, color.2),
                ),
            );
        }
    }

    fn lerp(a: Rgb, b: Rgb, t: f64) -> Rgb {
        let t = t.clamp(0.0, 1.0);
        let c = |x: u8, y: u8| (x as f64 + (y as f64 - x as f64) * t) as u8;
        (c(a.0, b.0), c(a.1, b.1), c(a.2, b.2))
    }

    /// Hash determinista y estable entre ejecuciones: `DefaultHasher` no
    /// garantiza serlo entre versiones de Rust, y aqui importa que la
    /// misma persona tenga siempre la misma foto.
    fn seed_of(key: &str) -> u64 {
        let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
        for byte in key.as_bytes() {
            hash ^= *byte as u64;
            hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
        }
        hash
    }

    /// Cielo + pista, con la pista en trapecio para que se lea como una
    /// perspectiva y no como dos bandas de color.
    pub fn render(key: &str, sport: Sport, variant: u32) -> Vec<u8> {
        let seed = seed_of(key).wrapping_add(variant as u64 * 7919);
        let mut canvas = Canvas::new();

        // Un tono de cielo por persona, para que no salgan diez fotos
        // identicas en el feed.
        let sky_variants: [(Rgb, Rgb); 4] = [
            ((0x1B, 0x3B, 0x5A), (0xF2, 0xA6, 0x5A)), // atardecer
            ((0x0E, 0x4D, 0x64), (0x9F, 0xD8, 0xE0)), // manana clara
            ((0x2A, 0x2D, 0x5E), (0xE0, 0x8D, 0x9A)), // amanecer
            ((0x11, 0x4B, 0x3F), (0xC9, 0xE3, 0x8B)), // mediodia verde
        ];
        let (sky_top, sky_bottom) = sky_variants[(seed % 4) as usize];

        let horizon = (HEIGHT as f64 * 0.46) as i32;

        for y in 0..horizon {
            let t = y as f64 / horizon as f64;
            let color = lerp(sky_top, sky_bottom, t);
            for x in 0..WIDTH as i32 {
                canvas.set(x, y, color);
            }
        }

        let (ground_far, ground_near) = match sport {
            // Tierra batida.
            Sport::Tennis => ((0xB2, 0x5A, 0x38), (0x8E, 0x40, 0x27)),
            // Tartan de pista de atletismo.
            Sport::Running => ((0x9C, 0x3F, 0x33), (0x6E, 0x28, 0x20)),
        };

        for y in horizon..HEIGHT as i32 {
            let t = (y - horizon) as f64 / (HEIGHT as i32 - horizon) as f64;
            let color = lerp(ground_far, ground_near, t);
            for x in 0..WIDTH as i32 {
                canvas.set(x, y, color);
            }
        }

        match sport {
            Sport::Tennis => draw_court(&mut canvas, horizon),
            Sport::Running => draw_track(&mut canvas, horizon),
        }

        draw_sun(&mut canvas, seed, horizon);
        draw_vignette(&mut canvas);

        encode(&canvas)
    }

    /// Ancho de la pista a una altura dada: casi un punto en el horizonte,
    /// mas ancha que la pantalla abajo. De ahi sale la perspectiva.
    fn court_half_width(y: i32, horizon: i32) -> f64 {
        let t = (y - horizon) as f64 / (HEIGHT as i32 - horizon) as f64;
        (WIDTH as f64 * 0.08) + t * (WIDTH as f64 * 0.62)
    }

    fn draw_court(canvas: &mut Canvas, horizon: i32) {
        let center = WIDTH as f64 / 2.0;
        let line = (0xF2, 0xF2, 0xEC);

        // Lineas de fondo y de saque, en horizontal.
        for (position, thickness) in [(0.18, 3.0), (0.45, 4.0), (0.82, 6.0)] {
            let y = horizon + ((HEIGHT as i32 - horizon) as f64 * position) as i32;
            let half = court_half_width(y, horizon);
            for dy in 0..thickness as i32 {
                for x in (center - half) as i32..(center + half) as i32 {
                    canvas.blend(x, y + dy, line, 0.85);
                }
            }
        }

        // Laterales y linea central, siguiendo la misma perspectiva.
        for y in horizon..HEIGHT as i32 {
            let half = court_half_width(y, horizon);
            let thickness = 2 + ((y - horizon) / 160);
            for dx in 0..thickness {
                canvas.blend((center - half) as i32 + dx, y, line, 0.85);
                canvas.blend((center + half) as i32 - dx, y, line, 0.85);
                canvas.blend(center as i32 + dx - thickness / 2, y, line, 0.5);
            }
        }
    }

    fn draw_track(canvas: &mut Canvas, horizon: i32) {
        let center = WIDTH as f64 / 2.0;
        let line = (0xF4, 0xF4, 0xF0);

        // Cuatro calles: las lineas se abren hacia abajo igual que la
        // pista de tenis, pero sin lineas horizontales.
        for lane in -2..=2 {
            for y in horizon..HEIGHT as i32 {
                let half = court_half_width(y, horizon);
                let x = center + (lane as f64 / 2.0) * half;
                let thickness = 2 + ((y - horizon) / 200);
                for dx in 0..thickness {
                    canvas.blend(x as i32 + dx, y, line, 0.8);
                }
            }
        }
    }

    /// Un sol bajo, que ademas hace de pelota: circulo calido con halo.
    fn draw_sun(canvas: &mut Canvas, seed: u64, horizon: i32) {
        let cx = (WIDTH as f64 * (0.18 + (seed % 5) as f64 * 0.14)) as i32;
        let cy = (horizon as f64 * 0.55) as i32;
        let radius = 62.0;
        let ball = (0xE8, 0xF0, 0x62);

        for y in (cy - 200)..(cy + 200) {
            for x in (cx - 200)..(cx + 200) {
                let dx = (x - cx) as f64;
                let dy = (y - cy) as f64;
                let distance = (dx * dx + dy * dy).sqrt();
                if distance <= radius {
                    canvas.blend(x, y, ball, 0.95);
                } else if distance <= radius * 3.0 {
                    // Halo que se desvanece, para que no quede un circulo
                    // pegado encima del cielo.
                    let t = 1.0 - (distance - radius) / (radius * 2.0);
                    canvas.blend(x, y, ball, 0.18 * t * t);
                }
            }
        }
    }

    /// Oscurece los bordes: sin esto la imagen se lee como un diagrama, no
    /// como una foto.
    fn draw_vignette(canvas: &mut Canvas) {
        let cx = WIDTH as f64 / 2.0;
        let cy = HEIGHT as f64 / 2.0;
        let max = (cx * cx + cy * cy).sqrt();

        for y in 0..HEIGHT as i32 {
            for x in 0..WIDTH as i32 {
                let dx = x as f64 - cx;
                let dy = y as f64 - cy;
                let t = (dx * dx + dy * dy).sqrt() / max;
                if t > 0.55 {
                    let alpha = ((t - 0.55) / 0.45).powf(1.8) * 0.55;
                    canvas.blend(x, y, (0, 0, 0), alpha);
                }
            }
        }
    }

    fn encode(canvas: &Canvas) -> Vec<u8> {
        let mut out = Vec::new();
        {
            let mut encoder = png::Encoder::new(&mut out, WIDTH, HEIGHT);
            encoder.set_color(png::ColorType::Rgb);
            encoder.set_depth(png::BitDepth::Eight);
            let mut writer = encoder.write_header().expect("png header");
            writer
                .write_image_data(&canvas.pixels)
                .expect("png image data");
        }
        out
    }
}

/// Sembrar una instalacion remota hablando por su API publica.
///
/// Existe por las fotos (ver el comentario de `--api` en `main`), y ademas
/// tiene la ventaja de que cada perfil pasa por exactamente las mismas
/// validaciones que una persona: si algo del alta esta roto, esto se entera.
///
/// Es idempotente: si el email ya existe hace login y actualiza el perfil, y
/// la foto solo se sube en el alta para no ir apilando copias del mismo
/// avatar hasta chocar con el maximo de 6.
///
/// Mete perfiles que no son personas en una instalacion que puede tener
/// gente de verdad. Para deshacerlo: `POST /admin/reset?confirm=BORRAR-TODO`,
/// que borra la instalacion **entera**, cuentas reales incluidas.
mod remote {
    use super::{FakeProfile, AVATAR_DIR, FAKE_PASSWORD, FAKE_PROFILES};
    use matchpoint_api::models::{Gender, Intention, SkillLevel, Sport};
    use serde_json::json;
    use std::path::Path;

    pub async fn seed_all(base: &str) -> anyhow::Result<()> {
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(60))
            .build()?;

        println!("Sembrando {} perfiles en {base}", FAKE_PROFILES.len());

        let (mut created, mut updated) = (0, 0);
        for (i, p) in FAKE_PROFILES.iter().enumerate() {
            // `/auth/register` y `/auth/login` estan limitados a 10 por
            // minuto y por IP. Diez altas de una tacada caben justo, pero una
            // segunda pasada son diez registros fallidos **mas** diez logins
            // y se choca con el 429 a mitad. Un respiro entre perfiles hace
            // que repetir el comando siga funcionando.
            if i > 0 {
                tokio::time::sleep(std::time::Duration::from_secs(7)).await;
            }
            match seed_one(&http, base, p, i).await {
                Ok(true) => {
                    created += 1;
                    println!("  + creado      {} ({})", p.email, p.display_name);
                }
                Ok(false) => {
                    updated += 1;
                    println!("  ~ actualizado {}", p.email);
                }
                Err(e) => eprintln!("  ! {} : {e}", p.email),
            }
        }

        println!("Listo: {created} creados, {updated} actualizados.");
        println!("Contrasena de todos: {FAKE_PASSWORD}");
        Ok(())
    }

    /// `true` si la cuenta se creo ahora; `false` si ya existia.
    async fn seed_one(
        http: &reqwest::Client,
        base: &str,
        p: &FakeProfile,
        index: usize,
    ) -> anyhow::Result<bool> {
        let creds = json!({ "email": p.email, "password": FAKE_PASSWORD });

        let res = post_auth(http, &format!("{base}/auth/register"), &creds).await?;

        // Registrar da 4xx si el email ya existe: entonces se entra con la
        // misma contrasena y se actualiza, que es lo que hace esto repetible.
        let (token, fresh) = if res.status().is_success() {
            (token_from(res).await?, true)
        } else {
            let login = post_auth(http, &format!("{base}/auth/login"), &creds).await?;
            if !login.status().is_success() {
                anyhow::bail!("ni registro ni login: {}", login.status());
            }
            (token_from(login).await?, false)
        };

        let profile = json!({
            "displayName": p.display_name,
            "birthDate": p.birth_date,
            "city": p.city,
            "bio": p.bio,
            "sports": p.sports.iter().map(sport_api).collect::<Vec<_>>(),
            "latitude": p.latitude,
            "longitude": p.longitude,
            "availability": p.availability,
            "gender": p.gender.map(gender_api),
            "intention": p.intention.map(intention_api),
            "yearsPlaying": p.years_playing,
            "club": p.club,
            "achievements": p.achievements,
            "avgPaceMinPerKm": p.avg_pace_min_per_km,
            "avgDistanceKm": p.avg_distance_km,
        });
        let r = http
            .patch(format!("{base}/me/profile"))
            .bearer_auth(&token)
            .json(&profile)
            .send()
            .await?;
        if !r.status().is_success() {
            anyhow::bail!(
                "perfil: {} {}",
                r.status(),
                r.text().await.unwrap_or_default()
            );
        }
        // Cuantas fotos tiene ya, segun el propio servidor. Se mira aqui y no
        // se deduce de "acabo de crear la cuenta": si una pasada anterior
        // creo el perfil pero se quedo sin subir la foto, la unica forma de
        // arreglarlo al repetir el comando es preguntar por el estado real.
        let has_photo = r
            .json::<serde_json::Value>()
            .await
            .ok()
            .and_then(|v| {
                v.get("photos")
                    .and_then(|p| p.as_array())
                    .map(|a| !a.is_empty())
            })
            .unwrap_or(false);

        if !p.skill_levels.is_empty() {
            let levels: Vec<_> = p
                .sports
                .iter()
                .zip(p.skill_levels.iter())
                .map(|(s, l)| json!({ "sport": sport_api(s), "level": level_api(l) }))
                .collect();
            let r = http
                .patch(format!("{base}/me/skill-levels"))
                .bearer_auth(&token)
                .json(&json!({ "levels": levels }))
                .send()
                .await?;
            if !r.status().is_success() {
                anyhow::bail!("niveles: {}", r.status());
            }
        }

        if !has_photo {
            upload_avatar(http, base, &token, index).await?;
        }

        Ok(fresh)
    }

    /// Llama a un endpoint de auth respetando su limitador.
    ///
    /// `/auth/register` y `/auth/login` van a 10 por minuto y por IP, y una
    /// segunda pasada gasta **dos** peticiones por perfil (el registro que
    /// falla porque ya existe, mas el login), asi que diez perfiles se comen
    /// veinte y la mitad se queda fuera. En vez de adivinar cuanto esperar,
    /// se lee la cabecera `retry-after` que el propio servidor manda con el
    /// 429 y se reintenta una vez.
    async fn post_auth(
        http: &reqwest::Client,
        url: &str,
        body: &serde_json::Value,
    ) -> anyhow::Result<reqwest::Response> {
        let res = http.post(url).json(body).send().await?;
        if res.status() != reqwest::StatusCode::TOO_MANY_REQUESTS {
            return Ok(res);
        }

        let wait = res
            .headers()
            .get("retry-after")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.parse::<u64>().ok())
            .unwrap_or(60)
            .min(90);
        println!("    (limite alcanzado, esperando {wait}s)");
        tokio::time::sleep(std::time::Duration::from_secs(wait + 1)).await;

        Ok(http.post(url).json(body).send().await?)
    }

    async fn token_from(res: reqwest::Response) -> anyhow::Result<String> {
        let body: serde_json::Value = res.json().await?;
        body.get("accessToken")
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .ok_or_else(|| anyhow::anyhow!("respuesta sin accessToken"))
    }

    /// Sube un avatar por el endpoint real de fotos.
    ///
    /// El cuerpo multipart se monta a mano en vez de activar la feature
    /// `multipart` de reqwest: son veinte lineas deterministas, y esa feature
    /// entraria tambien en el binario del servidor, que no sube nada a ningun
    /// sitio. Mismo criterio que el PNG dibujado a mano de este fichero.
    async fn upload_avatar(
        http: &reqwest::Client,
        base: &str,
        token: &str,
        index: usize,
    ) -> anyhow::Result<()> {
        let n = index % 6 + 1;
        let path = Path::new(AVATAR_DIR).join(format!("character{n}.jpg"));
        let bytes = std::fs::read(&path)
            .map_err(|e| anyhow::anyhow!("no se pudo leer {}: {e}", path.display()))?;

        const BOUNDARY: &str = "----matchpointseed7f3a9c1e";
        let mut body = Vec::new();
        body.extend_from_slice(format!("--{BOUNDARY}\r\n").as_bytes());
        // El campo tiene que llamarse `photo`: `me/photos.rs` se salta en
        // silencio cualquier otro nombre y contesta "No se ha recibido
        // ninguna foto", un 400 que no dice cual era el nombre bueno.
        body.extend_from_slice(
            b"Content-Disposition: form-data; name=\"photo\"; filename=\"avatar.jpg\"\r\n",
        );
        body.extend_from_slice(b"Content-Type: image/jpeg\r\n\r\n");
        body.extend_from_slice(&bytes);
        body.extend_from_slice(format!("\r\n--{BOUNDARY}--\r\n").as_bytes());

        let r = http
            .post(format!("{base}/me/photos"))
            .bearer_auth(token)
            .header(
                "content-type",
                format!("multipart/form-data; boundary={BOUNDARY}"),
            )
            .body(body)
            .send()
            .await?;

        if !r.status().is_success() {
            anyhow::bail!(
                "foto: {} {}",
                r.status(),
                r.text().await.unwrap_or_default()
            );
        }
        Ok(())
    }

    fn sport_api(s: &Sport) -> &'static str {
        match s {
            Sport::Tennis => "TENNIS",
            Sport::Running => "RUNNING",
        }
    }

    fn gender_api(g: Gender) -> &'static str {
        match g {
            Gender::Male => "MALE",
            Gender::Female => "FEMALE",
            Gender::Other => "OTHER",
        }
    }

    fn intention_api(i: Intention) -> &'static str {
        match i {
            Intention::Compete => "COMPETE",
            Intention::Train => "TRAIN",
            Intention::Learn => "LEARN",
            Intention::Fun => "FUN",
        }
    }

    fn level_api(l: &SkillLevel) -> &'static str {
        match l {
            SkillLevel::Beginner => "BEGINNER",
            SkillLevel::Intermediate => "INTERMEDIATE",
            SkillLevel::Advanced => "ADVANCED",
            SkillLevel::Competitive => "COMPETITIVE",
        }
    }
}
