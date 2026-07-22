# matchpoint-api-rust

Rust port of `services/api` (NestJS) using Axum + Diesel + diesel-async.

## Status: root module only

Ported so far (maps 1:1 to the NestJS src/ root files):

| NestJS file            | Rust file              |
|-------------------------|-------------------------|
| main.ts                 | src/main.rs             |
| app.module.ts            | src/app.rs              |
| app.controller.ts        | src/app/controller.rs   |
| app.service.ts           | src/app/service.rs       |
| (ConfigModule)           | src/config.rs            |
| (PrismaModule/Service)   | src/db.rs, src/state.rs |

Not ported yet: auth, discover, me, swipes, matches, chats, users.
Each will get its own `src/<module>/{controller,service,dto}.rs`, merged
into `src/app.rs` the same way `app.module.ts` lists them in `imports`.

## Build

This project needs a current Rust toolchain (edition 2024 support,
stable since Rust 1.85 / Feb 2025). Install via rustup as usual:

    rustup update stable
    cargo build

On Linux you'll also need Postgres/OpenSSL dev headers for diesel's
native pq bindings, e.g. on Ubuntu/Debian:

    sudo apt-get install libpq-dev libssl-dev pkg-config

## Run

    cp .env.example .env   # edit if needed
    docker compose up -d db   # same as the NestJS setup
    cargo run

Should behave identically to the Nest version for:
- GET /        -> "Hello World!"
- GET /health  -> { "ok": true }
