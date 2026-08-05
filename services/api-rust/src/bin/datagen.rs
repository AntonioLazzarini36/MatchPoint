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
    Gender, NewPreferences, NewProfile, NewUser, NewUserSkillLevel, SkillLevel, Sport,
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
    gender_preference: Option<Gender>,
    // Tennis-oriented credentials — left None for running-only profiles.
    years_playing: Option<i32>,
    club: Option<&'static str>,
    // Running-oriented credentials — left None for tennis-only profiles.
    avg_pace_min_per_km: Option<f64>,
    avg_distance_km: Option<f64>,
    achievements: &'static [&'static str],
    // One level per entry in `sports`, same order — kept as a parallel
    // list here only because it's static seed data typed by hand; the
    // real DB rows are a proper (user, sport) table, see models.rs.
    skill_levels: &'static [SkillLevel],
}

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
        gender_preference: None,
        years_playing: Some(5),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Intermediate],
    },
    FakeProfile {
        email: "marcos.running@example.com",
        display_name: "Marcos",
        birth_date: "1993-09-02",
        city: "Benalmádena",
        latitude: 36.5988,
        longitude: -4.5163,
        bio: "Corro 10k tres veces por semana. Busco gente para rodajes largos.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Male),
        gender_preference: None,
        years_playing: None,
        club: None,
        avg_pace_min_per_km: Some(5.2),
        avg_distance_km: Some(10.0),
        achievements: &["10K de Benalmádena 2025 - 45min"],
        skill_levels: &[SkillLevel::Intermediate],
    },
    FakeProfile {
        email: "sofia.multideporte@example.com",
        display_name: "Sofía",
        birth_date: "1999-01-20",
        city: "Málaga",
        latitude: 36.7213,
        longitude: -4.4214,
        bio: "Tenis y running, un poco de todo. Recién llegada a la ciudad.",
        sports: &[Sport::Tennis, Sport::Running],
        sports_wanted: &[Sport::Tennis, Sport::Running],
        gender: Some(Gender::Female),
        gender_preference: None,
        years_playing: Some(2),
        club: None,
        avg_pace_min_per_km: Some(7.0),
        avg_distance_km: Some(5.0),
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
        gender_preference: None,
        years_playing: Some(12),
        club: Some("Club de Tenis Torremolinos"),
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Advanced],
    },
    FakeProfile {
        email: "elena.maraton@example.com",
        display_name: "Elena",
        birth_date: "1988-06-30",
        city: "Fuengirola",
        latitude: 36.5411,
        longitude: -4.6247,
        bio: "Preparando media maratón. Ritmos suaves entre semana.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Female),
        gender_preference: None,
        years_playing: None,
        club: None,
        avg_pace_min_per_km: Some(5.8),
        avg_distance_km: Some(15.0),
        achievements: &["Media maratón de Málaga 2025 - 1h52"],
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
        gender_preference: None,
        years_playing: Some(1),
        club: None,
        avg_pace_min_per_km: None,
        avg_distance_km: None,
        achievements: &[],
        skill_levels: &[SkillLevel::Beginner],
    },
    FakeProfile {
        email: "carla.trail@example.com",
        display_name: "Carla",
        birth_date: "1995-08-22",
        city: "Mijas",
        latitude: 36.5959,
        longitude: -4.6372,
        bio: "Más de trail que de asfalto, pero acepto rodajes urbanos.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Female),
        gender_preference: None,
        years_playing: None,
        club: None,
        avg_pace_min_per_km: Some(6.5),
        avg_distance_km: Some(18.0),
        achievements: &["Trail Sierra de Mijas 21K - finisher 2024"],
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
        bio: "Empezando en esto del running, busco gente paciente.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender: Some(Gender::Female),
        gender_preference: None,
        years_playing: None,
        club: None,
        avg_pace_min_per_km: Some(7.5),
        avg_distance_km: Some(5.0),
        achievements: &[],
        skill_levels: &[SkillLevel::Beginner],
    },
    FakeProfile {
        email: "hugo.ambos@example.com",
        display_name: "Hugo",
        birth_date: "1994-02-27",
        city: "Torremolinos",
        latitude: 36.6203,
        longitude: -4.4998,
        bio: "Tenis en invierno, running en verano. Abierto a ambos.",
        sports: &[Sport::Tennis, Sport::Running],
        sports_wanted: &[Sport::Tennis, Sport::Running],
        gender: Some(Gender::Male),
        gender_preference: None,
        years_playing: Some(7),
        club: None,
        avg_pace_min_per_km: Some(5.5),
        avg_distance_km: Some(12.0),
        achievements: &[],
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

/// Escribe (si no existe ya) las fotos generadas de un perfil y devuelve
/// sus URLs publicas, en el mismo formato que las que sube la app
/// (`{public_base_url}/uploads/{archivo}`).
///
/// El nombre del archivo se deriva del email, asi que re-sembrar no
/// duplica archivos ni cambia las fotos de nadie.
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

    let mut urls = Vec::new();
    for variant in 0..count {
        let filename = format!("seed-{slug}-{variant}.png");
        let path = dir.join(&filename);
        if !path.exists() {
            let bytes = photo::render(email, sport, variant);
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
    let cfg = AppConfig::from_env();
    let pool = db::build_pool(&cfg.database_url).await;
    let mut conn = pool.get().await.expect("failed to get a DB connection");

    let args: Vec<String> = std::env::args().collect();

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
