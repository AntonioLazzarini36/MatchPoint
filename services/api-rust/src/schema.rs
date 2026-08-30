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

    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "SkillLevelValue"))]
    pub struct SkillLevelValue;

    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "Gender"))]
    pub struct Gender;

    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "ProposalStatus"))]
    pub struct ProposalStatus;

    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "Intention"))]
    pub struct Intention;

    #[derive(diesel::sql_types::SqlType, diesel::query_builder::QueryId)]
    #[diesel(postgres_type(name = "SessionOutcome"))]
    pub struct SessionOutcome;
}

diesel::table! {
    #[sql_name = "User"]
    users (id) {
        id -> Text,
        email -> Text,
        #[sql_name = "passwordHash"]
        password_hash -> Text,
        #[sql_name = "emailVerifiedAt"]
        email_verified_at -> Nullable<Timestamptz>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    #[sql_name = "EmailVerification"]
    email_verifications (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "codeHash"]
        code_hash -> Text,
        #[sql_name = "expiresAt"]
        expires_at -> Timestamptz,
        attempts -> Int4,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::table! {
    #[sql_name = "PasswordReset"]
    password_resets (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "codeHash"]
        code_hash -> Text,
        #[sql_name = "expiresAt"]
        expires_at -> Timestamptz,
        attempts -> Int4,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::table! {
    #[sql_name = "DeviceToken"]
    device_tokens (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        token -> Text,
        platform -> Text,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{Gender, Intention, Sport};

    #[sql_name = "Profile"]
    profiles (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "displayName"]
        display_name -> Text,
        #[sql_name = "birthDate"]
        birth_date -> Timestamptz,
        gender -> Nullable<Gender>,
        intention -> Nullable<Intention>,
        city -> Nullable<Text>,
        bio -> Nullable<Text>,
        photos -> Array<Text>,
        sports -> Array<Sport>,
        availability -> Int4,
        latitude -> Nullable<Double>,
        longitude -> Nullable<Double>,
        #[sql_name = "yearsPlaying"]
        years_playing -> Nullable<Int4>,
        club -> Nullable<Text>,
        achievements -> Array<Text>,
        #[sql_name = "avgPaceMinPerKm"]
        avg_pace_min_per_km -> Nullable<Double>,
        #[sql_name = "avgDistanceKm"]
        avg_distance_km -> Nullable<Double>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{Gender, Sport};

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
        gender_preference -> Nullable<Gender>,
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
        #[sql_name = "reviewedAt"]
        reviewed_at -> Nullable<Timestamptz>,
        #[sql_name = "reviewNote"]
        review_note -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{Sport, SkillLevelValue};

    #[sql_name = "SkillLevel"]
    skill_levels (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        sport -> Sport,
        level -> SkillLevelValue,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{ProposalStatus, Sport};

    #[sql_name = "Proposal"]
    proposals (id) {
        id -> Text,
        #[sql_name = "matchId"]
        match_id -> Text,
        #[sql_name = "proposedById"]
        proposed_by_id -> Text,
        sport -> Sport,
        #[sql_name = "placeName"]
        place_name -> Nullable<Text>,
        #[sql_name = "placeLat"]
        place_lat -> Nullable<Double>,
        #[sql_name = "placeLng"]
        place_lng -> Nullable<Double>,
        #[sql_name = "scheduledAt"]
        scheduled_at -> Timestamptz,
        status -> ProposalStatus,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
        #[sql_name = "updatedAt"]
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::SessionOutcome;

    #[sql_name = "SessionFeedback"]
    session_feedback (id) {
        id -> Text,
        #[sql_name = "proposalId"]
        proposal_id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        played -> Bool,
        outcome -> Nullable<SessionOutcome>,
        #[sql_name = "wouldRepeat"]
        would_repeat -> Nullable<Bool>,
        #[sql_name = "createdAt"]
        created_at -> Timestamptz,
    }
}

diesel::allow_tables_to_appear_in_same_query!(
    users,
    profiles,
    preferences,
    refresh_tokens,
    email_verifications,
    password_resets,
    device_tokens,
    swipes,
    matches,
    messages,
    reports,
    skill_levels,
    proposals,
    session_feedback,
);
