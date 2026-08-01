# matchpoint-api-rust

Rust port of the old `services/api` (NestJS), using Axum + Diesel + diesel-async.

## Status: port complete, superseded by CLAUDE.md

This file was written at the very start of the NestJS→Rust port, when only
the root module existed and the table below was a live todo list. The port
finished a long time ago — `auth`, `discover`, `me`, `swipes`, `matches`,
`chats`, `users` are all implemented, plus features that never existed in
the NestJS version at all (unmatch, report, rate limiting, refresh-token
rotation, real-time-ish chat polling support, etc.). `services/api` itself
is gone from the repo entirely.

For the current, maintained architecture reference, see `CLAUDE.md` at the
repo root ("Backend architecture" section) — that's kept in sync with the
code; this file is being left as-is below purely as a historical record of
where the port started.

Original root-module mapping (still accurate, just no longer the whole
picture):

| NestJS file            | Rust file              |
|-------------------------|-------------------------|
| main.ts                 | src/main.rs             |
| app.module.ts            | src/app.rs              |
| app.controller.ts        | src/app/controller.rs   |
| app.service.ts           | src/app/service.rs       |
| (ConfigModule)           | src/config.rs            |
| (PrismaModule/Service)   | src/db.rs, src/state.rs |

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
