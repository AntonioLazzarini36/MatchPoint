// @generated automatically by Diesel CLI.
//! Hecho a mano para que coincida exactamente con schema.prisma — Prisma
//! nunca convierte a snake_case, así que cada tabla/columna necesita su
//! #[sql_name] explícito.
//!
//! IMPORTANTE: diesel.toml NO debe tener una sección [print_schema] que
//! apunte a este archivo — si `diesel migration run` lo regenera
//! automáticamente, se pierde todo este trabajo manual (nombres de
//! módulo, #[sql_name], etc.), que es justo lo que pasó una vez.

pub mod sql_types {
    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "Sport"))]
    pub struct Sport;

    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "SwipeType"))]
    pub struct SwipeType;
}

diesel::table! {
    #[sql_name = "User"]
    users (id) {
        id -> Text,
        email -> Text,
        #[sql_name = "passwordHash"]
        password_hash -> Text,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::Sport;

    #[sql_name = "Profile"]
    profiles (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "displayName"]
        display_name -> Text,
        #[sql_name = "birthDate"]
        birth_date -> Timestamptz,
        city -> Nullable<Text>,
        bio -> Nullable<Text>,
        photos -> Array<Text>,
        sports -> Array<Sport>,
        latitude -> Nullable<Double>,
        longitude -> Nullable<Double>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::Sport;

    #[sql_name = "Preferences"]
    preferences (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "sportsWanted"]
        sports_wanted -> Array<Sport>,
        #[sql_name = "distanceKm"]
        distance_km -> Int4,
        #[sql_name = "ageMin"]
        age_min -> Int4,
        #[sql_name = "ageMax"]
        age_max -> Int4,
        #[sql_name = "genderPreference"]
        gender_preference -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    #[sql_name = "RefreshToken"]
    refresh_tokens (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "tokenHash"]
        token_hash -> Text,
        #[sql_name = "revokedAt"]
        revoked_at -> Nullable<Timestamptz>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{Sport, SwipeType};

    #[sql_name = "Swipe"]
    swipes (id) {
        id -> Text,
        #[sql_name = "fromUserId"]
        from_user_id -> Text,
        #[sql_name = "toUserId"]
        to_user_id -> Text,
        sport -> Sport,
        #[sql_name = "type"]
        swipe_type -> SwipeType,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::Sport;

    #[sql_name = "Match"]
    matches (id) {
        id -> Text,
        #[sql_name = "userAId"]
        user_a_id -> Text,
        #[sql_name = "userBId"]
        user_b_id -> Text,
        sport -> Sport,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::table! {
    #[sql_name = "Message"]
    messages (id) {
        id -> Text,
        #[sql_name = "matchId"]
        match_id -> Text,
        #[sql_name = "senderId"]
        sender_id -> Text,
        ciphertext -> Text,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "readAt"]
        read_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    #[sql_name = "Report"]
    reports (id) {
        id -> Text,
        #[sql_name = "reporterUserId"]
        reporter_user_id -> Text,
        #[sql_name = "reportedUserId"]
        reported_user_id -> Text,
        reason -> Text,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::allow_tables_to_appear_in_same_query!(
    users,
    profiles,
    preferences,
    refresh_tokens,
    swipes,
    matches,
    messages,
    reports,
);
