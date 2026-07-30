//! Test data generator. Run with `cargo run --bin datagen`.
//!
//! Seeds ~10 varied fake profiles (User + Profile + Preferences) so you
//! don't have to register accounts by hand to test discover/swipes/matches.
//! Idempotent: skips any email that already exists, so it's safe to re-run.
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
use matchpoint_api::models::{NewPreferences, NewProfile, NewUser, Sport};
use matchpoint_api::schema::{preferences, profiles, users};

const FAKE_PASSWORD: &str = "password123";

struct FakeProfile {
    email: &'static str,
    display_name: &'static str,
    birth_date: &'static str, // "YYYY-MM-DD"
    city: &'static str,
    bio: &'static str,
    sports: &'static [Sport],
    sports_wanted: &'static [Sport],
    gender_preference: Option<&'static str>,
}

const FAKE_PROFILES: &[FakeProfile] = &[
    FakeProfile {
        email: "lucia.tenis@example.com",
        display_name: "Lucía",
        birth_date: "1996-04-12",
        city: "Málaga",
        bio: "Tenis los fines de semana, nivel intermedio. Busco rival constante.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender_preference: None,
    },
    FakeProfile {
        email: "marcos.running@example.com",
        display_name: "Marcos",
        birth_date: "1993-09-02",
        city: "Benalmádena",
        bio: "Corro 10k tres veces por semana. Busco gente para rodajes largos.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender_preference: None,
    },
    FakeProfile {
        email: "sofia.multideporte@example.com",
        display_name: "Sofía",
        birth_date: "1999-01-20",
        city: "Málaga",
        bio: "Tenis y running, un poco de todo. Recién llegada a la ciudad.",
        sports: &[Sport::Tennis, Sport::Running],
        sports_wanted: &[Sport::Tennis, Sport::Running],
        gender_preference: None,
    },
    FakeProfile {
        email: "javier.club@example.com",
        display_name: "Javier",
        birth_date: "1990-11-05",
        city: "Torremolinos",
        bio: "Juego en el club desde hace años. Nivel avanzado, busco reto.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender_preference: None,
    },
    FakeProfile {
        email: "elena.maraton@example.com",
        display_name: "Elena",
        birth_date: "1988-06-30",
        city: "Fuengirola",
        bio: "Preparando media maratón. Ritmos suaves entre semana.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender_preference: None,
    },
    FakeProfile {
        email: "pablo.finde@example.com",
        display_name: "Pablo",
        birth_date: "2001-03-15",
        city: "Málaga",
        bio: "Tenis casual los sábados por la mañana, sin presión.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender_preference: None,
    },
    FakeProfile {
        email: "carla.trail@example.com",
        display_name: "Carla",
        birth_date: "1995-08-22",
        city: "Mijas",
        bio: "Más de trail que de asfalto, pero acepto rodajes urbanos.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender_preference: None,
    },
    FakeProfile {
        email: "diego.competitivo@example.com",
        display_name: "Diego",
        birth_date: "1992-12-01",
        city: "Málaga",
        bio: "Compito en torneos locales. Busco sparring de nivel alto.",
        sports: &[Sport::Tennis],
        sports_wanted: &[Sport::Tennis],
        gender_preference: None,
    },
    FakeProfile {
        email: "andrea.principiante@example.com",
        display_name: "Andrea",
        birth_date: "1998-05-18",
        city: "Benalmádena",
        bio: "Empezando en esto del running, busco gente paciente.",
        sports: &[Sport::Running],
        sports_wanted: &[Sport::Running],
        gender_preference: None,
    },
    FakeProfile {
        email: "hugo.ambos@example.com",
        display_name: "Hugo",
        birth_date: "1994-02-27",
        city: "Torremolinos",
        bio: "Tenis en invierno, running en verano. Abierto a ambos.",
        sports: &[Sport::Tennis, Sport::Running],
        sports_wanted: &[Sport::Tennis, Sport::Running],
        gender_preference: None,
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
    bio: Option<&str>,
    sports: Vec<Sport>,
    sports_wanted: Vec<Sport>,
    gender_preference: Option<&str>,
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
    let tx_gender_preference = gender_preference.map(|g| g.to_string());

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
                    city: tx_city,
                    bio: tx_bio,
                    photos: vec![],
                    sports,
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
                    gender_preference: tx_gender_preference,
                    updated_at: Utc::now(),
                })
                .execute(conn)
                .await?;

            Ok(())
        }
        .scope_boxed()
    })
    .await?;

    Ok(true)
}

async fn seed_fakes(conn: &mut AsyncPgConnection) -> anyhow::Result<()> {
    println!("Seeding {} fake profiles...\n", FAKE_PROFILES.len());

    let mut created = 0;
    let mut skipped = 0;

    for p in FAKE_PROFILES {
        let inserted = seed_one(
            conn,
            p.email,
            FAKE_PASSWORD,
            p.display_name,
            parse_birth_date(p.birth_date),
            Some(p.city),
            Some(p.bio),
            p.sports.to_vec(),
            p.sports_wanted.to_vec(),
            p.gender_preference,
        )
        .await?;

        if inserted {
            println!("  + creado   {} ({})", p.email, p.display_name);
            created += 1;
        } else {
            println!("  - ya existe {}", p.email);
            skipped += 1;
        }
    }

    println!("\nListo: {created} creados, {skipped} ya existían.");
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
        None,
        vec![Sport::Tennis, Sport::Running],
        vec![Sport::Tennis, Sport::Running],
        None,
    )
    .await?;

    if inserted {
        println!("Perfil propio creado: {email}");
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
        seed_fakes(&mut conn).await?;
    }

    Ok(())
}
