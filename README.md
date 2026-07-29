### MatchPoint es una app de citas basada en deporte. Aquí encuentras tu compañero/a perfecto/a para tu partido de tenis o tu sesión de running.

## Estado del backend

⚠️ **El backend se ha migrado de NestJS a Rust (Axum + Diesel + diesel-async).** La migración está completa y verificada. `services/api` (NestJS + Prisma) queda como legacy pendiente de borrar — no lo uses para desarrollo nuevo, usa `services/api-rust`.

## Cómo levantar todo

- DB:
    - `docker compose up -d db`

- Backend (Rust):
    - `cd services/api-rust`
    - Windows / vcpkg:
      ```powershell
      $env:VCPKG_ROOT = "C:\vcpkg"; $env:VCPKGRS_DYNAMIC = "0"; $env:VCPKGRS_TRIPLET = "x64-windows-static-md"
      cargo run
      ```
    - Requiere un `.env` con `DATABASE_URL` usando `127.0.0.1` (no `localhost`).
    - Escucha en `localhost:3000`.
    - `cargo run` nativo es el flujo diario (recompilar en contenedor es lento). `docker compose up -d --build api-rust` solo para verificar de vez en cuando que el `Dockerfile` sigue sano, o para despliegue real.

- Flutter / Frontend:
    - `cd apps/mobile`
    - `flutter run -d chrome` (o el emulador que uses)

## Migraciones (Diesel, ya no Prisma)

Cuándo: cualquier cambio de schema (tabla, columna, índice nuevo).

```powershell
diesel migration generate nombre_del_cambio
# editar up.sql / down.sql a mano
diesel migration run --database-url "postgresql://matchpoint:matchpoint@127.0.0.1:5432/matchpoint"
```
Después, actualizar `src/schema.rs` y `src/models.rs` a mano (con su `#[sql_name]`).

⚠️ `diesel.toml` debe tener `[print_schema]` comentado/desactivado — si no, regenera `schema.rs` y borra las anotaciones manuales.

## Additional information

- `apps/mobile/` → Flutter: frontend. Solo interfaz, sin base de datos propia. Llama al backend por HTTP.
- `services/api-rust/` → Backend actual (Rust, Axum + Diesel + diesel-async). Conecta a PostgreSQL. Escucha en `localhost:3000`.
- `services/api/` → Backend antiguo (NestJS + Prisma). **Pendiente de borrar** una vez se confirme el build + smoke test final del backend Rust en todos los entornos del equipo.
- Diesel: ORM. Genera `schema.rs`/`models.rs` (a mano). Ejecuta migraciones.
- PostgreSQL: base de datos. Corre en Docker. Vive en `localhost:5432`.
- Docker: por defecto solo levanta la DB. El backend Rust se corre nativo (`cargo run`) para desarrollo; el `docker compose up -d --build api-rust` es opcional (verificación puntual del Dockerfile / despliegue).

✅ docker-compose.yml ya está limpio: se eliminó el servicio api (NestJS antiguo). Solo quedan db y api-rust. api-rust ahora mapea al puerto 3000 (antes estaba en 3001 mientras convivía con el NestJS antiguo en ese puerto).
## Endpoints (API)

Todo bajo auth lleva `Authorization: Bearer <accessToken>` (15 min de vida; refresh dura 30 días).

#### Base / misc
- GET /
- GET /health

#### Auth (JWT access/refresh)
- POST /auth/register
- POST /auth/login
- POST /auth/refresh
- POST /auth/logout

#### Me (perfil + preferencias, autenticado)
- GET /me
- PATCH /me/profile
- PATCH /me/preferences

#### Discover
- GET /discover?sport=TENNIS|RUNNING

#### Swipes + match
- POST /swipes { toUserId, sport, type: LIKE|PASS } → { match, matchId?, swipeId }

#### Matches
- GET /matches → array de matches con info del otro usuario

#### Chats
- GET /chats/:matchId/messages
- POST /chats/:matchId/messages
- PATCH /chats/:matchId/read
(mensajes cifrados AES-256-GCM en DB, texto plano en la API; 403 si no eres miembro del match)

#### Users / Profiles
- GET /users/:userId/profile → perfil público (requiere auth), 404 si no existe

## Base de datos

Postgres, nombres en PascalCase/camelCase heredados de Prisma (no renombrados al migrar a Diesel).

- Enums: `Sport` (TENNIS, RUNNING), `SwipeType` (LIKE, PASS)
- **User**: id, email(unique), passwordHash, createdAt, updatedAt
- **Profile**: id, userId(unique FK), displayName, birthDate, city?, bio?, photos[], sports[], timestamps
- **Preferences**: id, userId(unique FK), sportsWanted[], distanceKm, ageMin, ageMax, genderPreference?, timestamps
- **RefreshToken**: id, userId(FK), tokenHash, revokedAt?, createdAt
- **Swipe**: id, fromUserId(FK), toUserId(FK), sport, type, createdAt — unique(fromUserId,toUserId,sport)
- **Match**: id, userAId(FK), userBId(FK), sport, createdAt — unique(userAId,userBId,sport)
- **Message**: id, matchId(FK), senderId(FK), ciphertext, createdAt, readAt?

## Próximos pasos

1. Confirmar build + smoke test final del backend Rust en todos los entornos → borrar `services/api` (NestJS+Prisma) y limpiar `docker-compose.yml`.
2. **Generador de datos de prueba**: script para crear ~10 perfiles falsos variados + un perfil propio, para no tener que registrar usuarios a mano cada vez. *(pendiente, se aborda más adelante)*
3. **Sistema de rating/nivel** (Elo vs Glicko-2): nueva tabla de partidos, cómo lo usa `discover`. Pieza central del producto, aún sin diseñar.
4. **Swagger / OpenAPI** para documentar y navegar los endpoints, e ir manteniéndolo actualizado. *(pendiente, se aborda más adelante, opcional pero recomendado)*
