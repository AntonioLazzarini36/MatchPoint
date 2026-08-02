# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Autonomy — do not stop mid-task

When given a task on this repo, execute it fully yourself, start to finish, without pausing to ask for permission or confirmation along the way. This includes:

- Running any checks, builds, tests, lints (`cargo fmt`/`clippy`/`build`/`test`, `flutter analyze`/`test`).
- Starting/stopping Docker, the backend, the Flutter app, seeding or querying the dev DB, curling local endpoints.
- Making implementation and scope decisions yourself (e.g. "should this fix also cover X related case?") instead of stopping to ask — use your best judgement, note the decision briefly in your summary, and keep going.

**The only point where you stop and wait is right before `git commit` / `git push`.** Get everything to a finished, verified state, then stop there for review. Do not use a clarifying-question tool (e.g. `AskUserQuestion`) for implementation/scope calls mid-task — only for things truly blocking that the user must decide before *any* further progress is possible, and even then, prefer picking the sensible default and mentioning it over stopping.

Do not ask "should I proceed?", "want me to also fix X?", or similar mid-task check-ins. Just do it, and report what you did when you stop at the commit/push checkpoint.

## What this is

MatchPoint is a sports-based dating app (tennis / running). Monorepo with a Rust backend and a Flutter frontend.

- `services/api-rust/` — **current backend**: Rust, Axum + Diesel + diesel-async, PostgreSQL. Listens on `localhost:3000`.
- `apps/mobile/` — Flutter frontend. No local database; talks to the backend over HTTP.
- `services/api-rust-markdown/` — untracked, local-only mirror of `api-rust/src` as `.md` files (one per source file, plus notes). Not part of the build; likely scratch/reference material, don't treat it as source of truth.
- `services/api` (NestJS + Prisma) has been fully removed — the backend was migrated to Rust. If you see references to it in old docs/comments, they're historical.

## Commands

### Backend (`services/api-rust/`)

```powershell
cd services/api-rust
# Windows/vcpkg env vars needed for the native pq bindings:
$env:VCPKG_ROOT = "C:\vcpkg"; $env:VCPKGRS_DYNAMIC = "0"; $env:VCPKGRS_TRIPLET = "x64-windows-static-md"
cargo run                      # daily dev workflow — native, fast
cargo run --bin datagen        # seed ~10 fake profiles (User+Profile+Preferences), password123, idempotent
cargo run --bin datagen -- --me you@example.com yourpass "Your Name" "City"   # seed just your own account
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo build --locked --all-features
cargo test --locked --all-features
```

Requires a `.env` with `DATABASE_URL` using `127.0.0.1` (not `localhost`). DB: `docker compose up -d db` (only the DB runs in Docker for normal dev; `docker compose up -d --build api-rust` is only for the occasional Dockerfile sanity check or real deploys).

Diesel migrations (schema changes):
```powershell
diesel migration generate name_of_change
# hand-edit up.sql / down.sql
diesel migration run --database-url "postgresql://matchpoint:matchpoint@127.0.0.1:5432/matchpoint"
```
Then hand-update `src/schema.rs` and `src/models.rs` (with `#[sql_name]` where needed — Diesel isn't auto-regenerating schema.rs, see below). `diesel.toml` must keep `[print_schema]` commented out, otherwise `diesel migration run` will regenerate `schema.rs` and wipe the manual annotations.

### Frontend (`apps/mobile/`)

```powershell
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome     # or your emulator
```

### CI (`.github/workflows/ci.yml`)

Three jobs, all triggered on every branch push: `backend` (fmt check, clippy `-D warnings`, build, test — against a real Postgres service container), `mobile` (analyze, test, `flutter build web --release`), `docker` (builds the `services/api-rust` image). Match these locally before pushing — clippy warnings and fmt diffs fail CI.

## Backend architecture

`api-rust` is a straight port of a former NestJS app, and the module shape still mirrors Nest's DI structure — useful mental model when navigating:

- `src/main.rs` — thin entrypoint, just calls `matchpoint_api::run()`.
- `src/lib.rs` — real startup logic (tracing init, config load, DB pool + connectivity check, CORS, router bind/serve). Everything is `pub mod`-ed here rather than in `main.rs` so app types count as "used" library surface for `cargo clippy --all-targets` (a bin-only crate would false-flag model types as dead code).
- `src/app.rs` — equivalent of `app.module.ts`: builds the root `Router` by `.merge()`-ing every feature module's router, then `.with_state(AppState)`.
- `src/state.rs` — `AppState { db: DbPool, config: Arc<AppConfig>, rate_limiter: RateLimiter }`, cloned into every handler (Axum's answer to Nest's constructor DI).
- `src/config.rs` — equivalent of `ConfigModule`: reads all env vars once at startup into `AppConfig`, panics fast if something required is missing.
- `src/db.rs` — Diesel-async connection pool (bb8).
- Each feature module (`auth/`, `discover/`, `me/`, `swipes/`, `matches/`, `chats/`, `users/`, `app/`) follows the same three-file shape as its Nest ancestor: `controller.rs` (Axum router + handlers, maps errors to `StatusCode`), `service.rs` (business logic, DB queries), and `dto.rs` where request/response shapes need their own types. `auth/` additionally has `jwt.rs` (sign/verify) and `rate_limit.rs` (in-memory per-IP sliding-window limiter, applied only to `/auth/login|register|email-available`); `chats/` additionally has `crypto.rs` (AES-256-GCM message encryption — ciphertext at rest, plaintext over the API).
- `src/models.rs` / `src/schema.rs` — Diesel models and schema, hand-maintained (see migrations note above; do not expect `schema.rs` to auto-regenerate).
- `src/bin/datagen.rs` — extra binary in the same crate (auto-discovered by Cargo, no `Cargo.toml` change needed) for seeding test data; see Commands above.
- `src/openapi.rs` — OpenAPI spec aggregator (`utoipa`), served as Swagger UI + JSON via `app.rs`. See "OpenAPI docs" below.

### Auth & data model

- JWT access/refresh: access token lives 15 min, refresh 30 days. Authenticated routes take `Authorization: Bearer <accessToken>`. Refresh tokens rotate on every use (old one deleted, new one issued) — the mobile client stores both tokens and `ApiClient` transparently refreshes-and-retries on a 401.
- **Gotcha:** `auth/service.rs` SHA-256-digests a refresh token before bcrypt-hashing it for storage (`refresh_token_digest`) — do not bcrypt-hash a raw token directly. bcrypt only looks at the first 72 bytes of its input, and two refresh JWTs for the same user share an identical prefix well past that (header + `sub` + `email` claims are byte-identical; only `exp`, near the end of the payload, differs), so bcrypt would treat every token ever issued to a user as equal to the current one — silently defeating rotation.
- DB table/column names are PascalCase/camelCase, inherited from the original Prisma schema — intentionally not renamed when porting to Diesel, so expect `#[sql_name]` annotations in `models.rs` rather than idiomatic snake_case.
- Core tables: `User`, `Profile` (1:1 via `userId`; includes nullable `latitude`/`longitude` set via manual place-search, Hinge-style — `city` doubles as the display name of the chosen place), `Preferences` (1:1 via `userId`), `RefreshToken`, `Swipe` (unique per `fromUserId,toUserId,sport`), `Match` (unique per `userAId,userBId,sport`), `Message` (ciphertext in DB, decrypted plaintext in API responses).
- Enums: `Sport` (TENNIS, RUNNING), `SwipeType` (LIKE, PASS).

### API surface

- Auth: `POST /auth/register|login|refresh|logout`, `GET /auth/email-available?email=`. `login`/`register`/`email-available` are rate-limited (10 req/60s per IP, 429 past that).
- Me: `GET /me`, `PATCH /me/profile` (does **not** accept `photos` — that field only exists on the dedicated photo endpoints below), `PATCH /me/preferences`, `POST /me/photos` (multipart, enforces `MAX_PHOTOS`=6 + type/size validation), `DELETE /me/photos` (can't delete the last photo)
- Discover: `GET /discover?sport=TENNIS|RUNNING` — excludes already-swiped users and filters by the caller's `ageMin`/`ageMax` and `distanceKm` preferences (age falls back to 18-60 if no preferences row yet; distance via Haversine against `Profile.latitude/longitude`, no PostGIS — neither the viewer nor a candidate missing coordinates is affected by the distance filter). Does **not** filter by `genderPreference` — no gender field stored on `Profile` yet.
- Swipes: `POST /swipes { toUserId, sport, type: LIKE|PASS }` → `{ match, matchId?, swipeId }`
- Matches: `GET /matches` (includes `lastMessage` decrypted preview + `unreadCount` per match), `DELETE /matches/:matchId` (unmatch — deletes the match + its chat; only a match member can call it)
- Chats: `GET/POST /chats/:matchId/messages`, `PATCH /chats/:matchId/read` (403 if not a match member)
- Users: `GET /users/:userId/profile` (public profile, still requires auth; 404 if missing), `POST /users/:userId/report { reason }` (logs a report for review only — does not touch any match/chat)
- Misc: `GET /`, `GET /health`

There's no rating/skill-level system yet (Elo vs Glicko-2 undecided) — `discover` currently has nothing to rank matches by skill.

There's no Block feature — deliberately removed (see git history on `feature/rust-backend`); unmatch (cuts contact) + report (flags for review) were judged to cover what block would have.

### OpenAPI docs

Swagger UI at `http://localhost:3000/docs`, raw spec at `/api-docs/openapi.json` (`utoipa` + `utoipa-swagger-ui`, mounted in `app.rs`). When adding an endpoint: derive `ToSchema` on its DTO/response types, add a `#[utoipa::path(...)]` block above the handler (copy a neighboring one in the same `controller.rs` as a template), then register the handler and any new schema types in `src/openapi.rs`'s `paths(...)`/`components(schemas(...))`. Missing/mismatched entries fail `cargo build`, so the docs can't silently drift from the code.

**Gotcha:** in `request_body`/`responses(body = ...)`, always reference the type by its **short name** (`body = MeResponse`), never a fully-qualified path (`body = crate::me::service::MeResponse`) — with utoipa 4.x the latter produces a broken literal `$ref` (`crate.me.service.MeResponse`) that doesn't match how the type gets registered in `components/schemas` (by short name), and Swagger UI shows "could not resolve reference" errors. This means the short name has to be `use`-imported into `controller.rs` purely for the macro, which clippy then flags as `unused_imports` since nothing else in the file references it by that path — put `#[allow(unused_imports)]` above that `use` (every `controller.rs` already does this; copy the pattern).

**Gotcha:** `utoipa-swagger-ui`'s build script downloads the Swagger UI static assets at compile time via the system `curl` binary. `services/api-rust/Dockerfile`'s builder stage (`rust:1-slim-bookworm`) installs `curl` + `ca-certificates` for this — don't remove them, `cargo build --release` inside the image fails without them (`utoipa-swagger-ui` build script panics: `curl` not found).

## Frontend architecture

`apps/mobile/lib/` is feature-organized:
- `app/` — app shell, routing (`router.dart`, `routes.dart`).
- `core/` — cross-feature: `network/` (`api_client.dart` — HTTP client with transparent 401-refresh-and-retry, `api.dart` — backend base URL/singleton), `auth/` (`auth_gate.dart`), `storage/` (`token_storage.dart` — access + refresh tokens, secure storage), `theme/`, `ui/` (shared widgets: `ui/widgets/` has per-feature subfolders like `chat`, `discovery`, `matches`, `onboarding`; `ui/dialogs/` has generic confirm/report dialogs; `ui/profile/` has profile-display widgets shared between own/other profile screens).
- `features/` — one folder per feature (`auth`, `discovery`, `matches`, `onboarding`, `profile`, `welcome`, `courts` — tennis club map, `flutter_map` + OSM tiles, Overpass API for real club data, entered from the AppBar on Matches), each with its own `models/`, `screens/`, `services/`.
