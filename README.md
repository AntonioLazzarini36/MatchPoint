### MatchPoint es una app para encontrar con quién jugar al tenis: a tu nivel, cerca de ti, y cuando los dos podéis.

> **No es una app de citas con deporte de excusa** — el objetivo es organizar el partido o la salida,
> no una cita. De ahí que el perfil gire alrededor del nivel y de señales que se puedan reconocer
> (años jugando, club, torneos) y que la app no se quede en el match: sigue hasta el partido
> acordado, y guarda lo que pasó. Ver "Reposicionamiento de producto" en `claude_helpers/status.md`.

## Estado del backend

✅ **El backend se ha migrado de NestJS a Rust (Axum + Diesel + diesel-async).** La migración está completa y verificada. `services/api` (NestJS + Prisma) ya se borró del todo — si ves referencias a él en comentarios o docs viejos, son históricas.

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
  - Swagger UI (documentación interactiva de la API): `http://localhost:3000/docs`. Spec OpenAPI en crudo: `http://localhost:3000/api-docs/openapi.json`.
- Flutter / Frontend:
  - `cd apps/mobile`
  - `flutter run -d chrome` (o el emulador que uses)
## Probar en el móvil (no solo Chrome/emulador)

Para correr la app en un móvil físico (Android o iOS) durante desarrollo, conectado
por USB o por la misma red WiFi que el ordenador:

1. Averigua la IP LAN del ordenador (Windows: `ipconfig`, busca el adaptador WiFi/
   Ethernet activo — ej. `192.168.1.33`, no la de adaptadores virtuales tipo WSL/
   Hyper-V que empiezan por `172.x`).
2. El backend ya escucha en `0.0.0.0` (todas las interfaces), no hace falta tocar
   nada ahí — pero la primera vez que un móvil se conecte, Windows puede mostrar
   un popup de "Firewall de Windows Defender" pidiendo permitir la conexión: hay
   que aceptarlo (o crear la regla a mano, `New-NetFirewallRule` para el puerto
   3000, perfil "Private", requiere PowerShell como administrador).
3. Levanta la app apuntando a esa IP en vez de `localhost`/`10.0.2.2`:
   ```powershell
   cd apps/mobile
   flutter run --dart-define=API_BASE_URL=http://192.168.1.33:3000
   ```
   (cambia la IP por la tuya). `flutter devices` te lista el móvil conectado si
   Flutter ya lo detecta (USB debugging activado en Android, o confiar el
   ordenador desde el móvil en iOS).

## Generador de datos de prueba

Para no tener que registrar usuarios a mano cada vez, hay un binario extra dentro del mismo crate (`src/bin/datagen.rs`, se detecta solo, no requiere tocar `Cargo.toml`):

```powershell
cd services/api-rust
cargo run --bin datagen
```

Esto siembra ~10 perfiles falsos variados (User + Profile + Preferences), todos con la contraseña `password123`. Es idempotente: si vuelves a ejecutarlo, salta los emails que ya existan en vez de duplicarlos o petar.

Para crear tu propio perfil sin tocar los falsos:
```powershell
cargo run --bin datagen -- --me tu@email.com tu_password "Tu Nombre" "Tu Ciudad"
```

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
- `services/api/` → ✅ **ya no existe.** Backend antiguo (NestJS + Prisma), borrado del todo tras confirmar el build + smoke test del backend Rust. Si ves referencias a él en comentarios/docs viejos, son históricas.
- Diesel: ORM. Genera `schema.rs`/`models.rs` (a mano). Ejecuta migraciones.
- PostgreSQL: base de datos. Corre en Docker. Vive en `localhost:5432`.
- Docker: por defecto solo levanta la DB. El backend Rust se corre nativo (`cargo run`) para desarrollo; el `docker compose up -d --build api-rust` es opcional (verificación puntual del Dockerfile / despliegue).
  ✅ `docker-compose.yml` ya está limpio: se eliminó el servicio `api` (NestJS antiguo). Solo quedan `db` y `api-rust`. `api-rust` ahora mapea al puerto **3000** (antes estaba en 3001 mientras convivía con el NestJS antiguo en ese puerto).

## Endpoints (API)

Todo bajo auth lleva `Authorization: Bearer <accessToken>` (15 min de vida; refresh dura 30 días, rota en cada uso). Ver también Swagger UI en `/docs` para la spec completa siempre al día.

#### Base / misc
- GET /
- GET /health → consulta la base de datos de verdad (timeout 2s) y devuelve **503** si no responde; un healthcheck que siempre dice `{ok:true}` es peor que ninguno
#### Auth (JWT access/refresh)
- POST /auth/register
- POST /auth/login
- POST /auth/refresh
- POST /auth/logout
- GET /auth/email-available?email=
- POST /auth/send-verification → manda un código de 6 dígitos al email de la cuenta (autenticado: así sólo puedes pedirlo para la tuya y nadie puede usarlo para bombardear el buzón de otro). 15 min de vida, 5 intentos, 60s entre reenvíos
- POST /auth/verify-email { code } → marca el email como verificado
  (`login`/`register`/`email-available` tienen rate limit: 10 req/60s por IP, 429 a partir de ahí)
  (los dos de verificación responden 503 si `EMAIL_VERIFICATION_ENABLED=false` — ver "Despliegue" abajo)
#### Me (perfil + preferencias, autenticado)
- GET /me (incluye `emailVerified` y `emailVerificationEnabled`)
- DELETE /me → **borra la cuenta entera**, sin vuelta atrás: perfil, fotos, swipes, matches, mensajes y propuestas. Las tablas caen por `ON DELETE CASCADE`, pero los ficheros de las fotos se borran a mano (ningún cascade toca el disco). La confirmación — escribir "BORRAR" — la pide la app, no el endpoint
- PATCH /me/profile (ya no acepta `photos` — eso solo se gestiona por los endpoints de abajo; incluye `yearsPlaying`/`club`/`achievements`/`avgPaceMinPerKm`/`avgDistanceKm`)
- PATCH /me/preferences (`genderPreference` se manda como null explícito para volver a "cualquiera" — omitirlo significa "no lo toques")
- GET /me/notifications → `{ unreadMessages, pendingProposals }`, contadores para los badges de la barra de navegación
- PATCH /me/skill-levels (upsert de nivel por deporte — `{ levels: [{ sport, level }] }`, no toca los deportes no incluidos)
- POST /me/photos (multipart, máx. 6 fotos, valida tipo/tamaño)
- DELETE /me/photos (no deja borrar la última foto)
#### Discover
- GET /discover?sport=TENNIS|RUNNING → candidatos con perfil completo (foto + ubicación), filtrados por edad/distancia/género, con `distanceKm`, `matchesYourLevel` y `likesYou`, ordenados por quién te ha dado like y quién juega a tu nivel
  (excluye a quien ya swipeaste y filtra por `ageMin`/`ageMax`, `distanceKm` y `genderPreference` reales de tus preferencias — distancia por Haversine contra `Profile.latitude/longitude`, sin PostGIS; ni viewer ni candidato sin ubicación seteada se ven afectados por el filtro, y quien no ha declarado género tampoco se excluye al filtrar por género. Qué deporte pedir lo decide el cliente a partir de `Preferences.sportsWanted`)
#### Swipes + match
- POST /swipes { toUserId, sport, type: LIKE|PASS } → { match, matchId?, swipeId }
#### Matches
- GET /matches → array de matches con info del otro usuario, deporte, último mensaje (desencriptado) y contador real de no-leídos
- DELETE /matches/:matchId → deshace el match (borra match + chat; solo un miembro del match puede hacerlo)
#### Proposals (quedar de verdad)
- POST /matches/:matchId/proposals { sport, scheduledAt, placeName?, placeLat?, placeLng? } → crea la propuesta y **cancela cualquier otra que siguiera pendiente en ese match** (dos ofertas vivas a la vez dejan a ambas partes sin saber cuál aceptan). El `sport` **no tiene que coincidir con el del match**: ese sólo dice por qué feed os cruzasteis. Basta con que lo practiquéis los dos, para que quien juega al tenis y además corre pueda proponer cualquiera de los dos en la misma conversación
- GET /matches/:matchId/proposals → historial de propuestas del match, más reciente primero
- PATCH /proposals/:proposalId { action: ACCEPT|DECLINE|CANCEL } → aceptar/rechazar solo lo puede hacer quien la recibió, y solo mientras está PENDING. `CANCEL` funciona también sobre una ya ACCEPTED (los planes cambian) y en ese caso puede hacerlo cualquiera de los dos; mientras solo está propuesta, cancelar es cosa de quien la hizo
- GET /me/proposals → tu agenda: sesiones aceptadas **y** propuestas pendientes aún por jugar, de todos tus matches, con lo justo del otro usuario para pintar la fila
#### Chats
- GET /chats/:matchId/messages
- POST /chats/:matchId/messages
- PATCH /chats/:matchId/read
  (mensajes cifrados AES-256-GCM en DB, texto plano en la API; 403 si no eres miembro del match)
#### Users / Profiles
- GET /users/:userId/profile → perfil público (requiere auth), 404 si no existe
- POST /users/:userId/report { reason } → registra un reporte para revisión; no borra el match ni corta contacto (para eso, unmatch)
## Base de datos

Postgres, nombres en PascalCase/camelCase heredados de Prisma (no renombrados al migrar a Diesel).

- Enums: `Sport` (TENNIS, RUNNING), `SwipeType` (LIKE, PASS), `SkillLevelValue` (BEGINNER, INTERMEDIATE, ADVANCED, COMPETITIVE), `Gender` (MALE, FEMALE, OTHER), `ProposalStatus` (PENDING, ACCEPTED, DECLINED, CANCELLED), `Intention` (COMPETE, TRAIN, LEARN, FUN), `SessionOutcome` (WON, LOST, DRAW — sólo tenis)
- **User**: id, email(unique), passwordHash, createdAt, updatedAt
- **Profile**: id, userId(unique FK), displayName, birthDate, gender?, intention?, city?, bio?, photos[], sports[], **availability**, latitude?, longitude?, yearsPlaying?, club?, achievements[], avgPaceMinPerKm?, avgDistanceKm?, timestamps
  - `availability` es un entero de 21 bits (`bit = día * 3 + franja`, lunes primero, mañana/tarde/noche): el horario que esa persona **suele** tener libre. No filtra ni ordena nada — se enseña a quien va a proponer una quedada para que no elija un hueco imposible.
- **Preferences**: id, userId(unique FK), sportsWanted[], distanceKm, ageMin, ageMax, genderPreference?(`Gender`), timestamps
- **Proposal**: id, matchId(FK), proposedById(FK), sport, placeName?, placeLat?, placeLng?, scheduledAt, status, timestamps — un plan concreto para jugar, colgado de un match
- **SkillLevel**: id, userId(FK), sport, level, timestamps — unique(userId,sport). Nivel auto-declarado, no un rating calculado — ver punto 3 abajo.
- **RefreshToken**: id, userId(FK), tokenHash, revokedAt?, createdAt
- **Swipe**: id, fromUserId(FK), toUserId(FK), sport, type, createdAt — unique(fromUserId,toUserId,sport)
- **Match**: id, userAId(FK), userBId(FK), sport, createdAt — unique(userAId,userBId,sport)
- **Message**: id, matchId(FK), senderId(FK), ciphertext, createdAt, readAt?
- **SessionFeedback**: id, proposalId(FK), userId(FK), played, outcome?, wouldRepeat?, timestamps — unique(proposalId,userId). Lo que cierra el bucle: de aquí sale "habéis jugado N veces".
- **DeviceToken**: id, userId(FK), token(unique), platform, timestamps — para las push (FCM)
- **Report**: id, reporterId(FK), reportedId(FK), reason, reviewedAt?, reviewNote?, createdAt

## Próximos pasos

1. ✅ Confirmar build + smoke test final del backend Rust en todos los entornos → borrada la carpeta `services/api` (NestJS+Prisma), `docker-compose.yml` limpio.
2. ✅ **Generador de datos de prueba** (`cargo run --bin datagen`), ver sección de arriba.
3. **Sistema de rating/nivel** (Elo vs Glicko-2): la mitad corta ya está — nivel auto-declarado por deporte (`SkillLevel`, ver arriba) + experiencia (años jugando, club, torneos/logros), editable desde onboarding y Settings, visible en Discovery/perfil público. Lo que falta es la parte larga: rating *calculado* a partir de resultados de partidos reales — no existe ni el concepto de "cargar el resultado de un partido" todavía, ni cómo lo usaría `discover` para emparejar.
4. ✅ **Swagger / OpenAPI** (`utoipa` + `utoipa-swagger-ui`), ver `http://localhost:3000/docs` arriba y "Documentar un endpoint nuevo" abajo.
5. ✅ **Pasada de seguridad/fiabilidad (2026-08-01)**: secretos JWT obligatorios, rate limiting en auth, refresh token real en el móvil (+ arreglado un bug de bcrypt que dejaba la rotación sin efecto), fix de un par de crashes/bugs de UI, unread real en Matches, polling en el chat, buscador de matches. Detalle completo en `claude_helpers/status.md`.
6. ✅ **Ubicación real estilo Hinge** (`feat/manual-location`): sin GPS, se escribe un sitio y se elige de sugerencias reales (Nominatim/OSM); `/discover` ya filtra por `distanceKm` real (Haversine), editable en cualquier momento desde Settings.
7. ✅ **Mapa de clubes de tenis, MVP** (`feat/tennis-court-map`, rama viva para seguir iterando): clubes reales cerca vía Overpass/OSM, proponer un partido a un match existente. Sin reservas/disponibilidad real todavía (issue #18 completo).
8. ✅ **Rediseño de Discovery** (2026-08-02): deck de una tarjeta a la vez → columna de hasta 4 tarjetas horizontales de altura fija, sin superponerse, arrastrables para like/pass, preview al tocar.
9. ✅ **Bug de Discovery ignorando el/los deporte(s) reales del usuario** (2026-08-02/03): antes pedía siempre solo tenis sin importar qué eligió el usuario; ahora respeta `Profile.sports` de verdad y se puede editar desde Settings.
10. ✅ **Segunda pasada de validación de inputs (2026-08-03)**: rangos/longitudes en `/me/profile` y `/me/preferences` (antes sin ningún límite server-side), email/password mínimos en registro (antes solo el cliente los chequeaba, trivial de saltarse), motivo de reporte acotado.
11. ✅ **Filtros de Discovery y campo de género (2026-08-04)**: la hoja de filtros (edad, deportes que quieres ver, género) es real y se abre desde Discovery y desde Ajustes; `Preferences.sportsWanted` y `genderPreference` por fin **hacen algo** — antes se guardaban y no los leía nadie.
12. ✅ **Partidos con estado (2026-08-04, rehecho el 2026-08-29)**: tabla `Proposal` y su ciclo completo (proponer → aceptar/rechazar/cancelar), pantalla propia y ficha con mapa. Antes "proponer un partido" era un mensaje de texto que se perdía scrolleando. Hoy las propuestas **son** mensajes otra vez, pero con estado: fichas dentro de la conversación, ordenadas por cuándo se propusieron, que se apilan si mandas varias y se quedan tachadas si se cancelan. Se pueden tener **varios partidos abiertos con la misma persona** (una propuesta nueva ya no cancela la pendiente), y hay historial de los ya jugados con el resultado (`GET /me/proposals/history`).
13. ✅ **Verificación de email (2026-08-05)**: código de 6 dígitos, backend y pantalla. Apagable con `EMAIL_VERIFICATION_ENABLED` mientras no haya un dominio de correo propio — ver "Despliegue".
14. ✅ **Borrar cuenta (2026-08-05)**: `DELETE /me`, con confirmación escribiendo "BORRAR". Cierra el hueco de RGPD.
15. ✅ **Identidad, firma y push (2026-08-21/22)**: `com.matchpoint.app`, keystore de release propio, nombre e icono derivados del logo, y notificaciones push por FCM probadas en producción con la app cerrada. Cola de moderación (`/admin/reports`) y rate limiting por usuario fuera de auth.
16. ✅ **Sólo tenis, y el "cuándo" manda (2026-08-27/29)**: running queda **apagado, no borrado** (`core/utils/app_sports.dart` es el único interruptor; el enum, la columna y el filtro siguen enteros). Descubrir dejó de ser un mazo de caras y pasó a ser una búsqueda que empieza por *cuándo puedes jugar*: el feed filtra y ordena por franjas en común, el PASS caduca a los 30 días (permanente vaciaba el feed para siempre a esta densidad) y deshacer un match ya no deja a los dos invisibles de por vida. Icono, logo y textos son de tenis. Hay analítica midiendo el embudo, y política de privacidad y términos en `docs/`.
17. ✅ **Horario semanal y avatares (2026-08-22/23)**: la disponibilidad pasó de seis franjas gruesas que no se veían en ninguna pantalla a una rejilla semanal que se enseña **al proponer una quedada**, atenuando los días y horas en que la otra persona no suele poder (sin bloquear: es referencia, no agenda). Y el paso de fotos ofrece seis avatares de la app, para no obligar a subir una foto propia para poder empezar.
18. **Para publicar en Google Play**: la política de privacidad y los términos ya están escritos (`docs/`, listos para GitHub Pages) y el formulario de Data Safety está respondido campo a campo en `claude_helpers/data_safety.md`. Quedan tareas del usuario: publicar esas páginas, copia del keystore, rotar la clave de Firebase — y **apagar `DEMO_SEED_NEW_USERS` y borrar los perfiles sembrados antes de publicar**, que con ellos encendidos Play lo trata como comportamiento engañoso.
19. Sin decidir todavía / sin definir alcance: rediseño general de UI (`redesign/ui-overhaul`), suite de tests (`test/full-app-suite`, la cobertura sigue siendo mínima), super-like, y **login con Google/Apple** — esto último necesita credenciales externas (proyecto de Google Cloud, cuenta de Apple Developer) que hay que crear antes de que escribir código sirva de algo.  Detalle completo en `claude_helpers/status.md`.

## Despliegue

La app corre en producción en **Railway** (API + Postgres). El paso a paso completo — variables,
volumen para las fotos, y qué se rompe sin cada cosa — está en **`services/api-rust/DEPLOY.md`**.

Lo mínimo que conviene saber:

- Con `APP_ENV=production` el proceso **se niega a arrancar** si los secretos siguen siendo los del
  repo (que son públicos), si `CORS_ALLOWED_ORIGINS` está sin poner o si `PUBLIC_BASE_URL` sigue
  apuntando a localhost. Un fallo ruidoso al desplegar es mejor que un servicio en pie con secretos
  publicados.
- **Las migraciones van dentro del binario** y se aplican al arrancar: un despliegue no tiene consola
  donde correr `diesel migration run`.
- **Hace falta un volumen montado en `/app/uploads`.** Sin él, el sistema de ficheros del contenedor
  se borra en cada despliegue y todo el mundo pierde sus fotos — y como `/discover` exige al menos
  una foto, esos perfiles desaparecen del feed.
- `CORS_ALLOWED_ORIGINS=none` es la respuesta correcta mientras sólo exista la app móvil: CORS lo
  aplican los navegadores, y una app nativa no pasa por ahí. Cuando haya web, su URL.

Para compilar la app apuntando al backend desplegado:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://matchpoint-production-bfd0.up.railway.app
```

Sin `--dart-define`, la app cae en `10.0.2.2:3000` (el alias del emulador): instala bien y luego
**ninguna petición llega**, que es la peor forma de fallar. Comprobarlo antes de repartir el APK
buscando la URL dentro de `lib/arm64-v8a/libapp.so`. Añadir `--split-per-abi` si hay que enviarlo por
chat: el universal pesa ~55 MB y el de arm64 ~22 MB.

## Documentar un endpoint nuevo (OpenAPI)

Al añadir un endpoint en `services/api-rust`:

1. Deriva `utoipa::ToSchema` en su DTO de request y en su struct de respuesta (junto a `Serialize`/`Deserialize`).
2. Añade un bloque `#[utoipa::path(...)]` justo encima del handler en `controller.rs` (copia uno del mismo módulo como plantilla — método, `path`, `tag`, `request_body`/`params` si aplica, `security(("bearerAuth" = []))` si requiere JWT, y `responses(...)`).
3. Registra el handler y los tipos nuevos en `src/openapi.rs` (`paths(...)` y `components(schemas(...))`).

`cargo build`/`cargo clippy` fallan si algo queda mal referenciado, así que es difícil que la doc se desincronice del código sin que se note.

⚠️ En `request_body`/`responses(body = ...)` usa siempre el **nombre corto del tipo** (`body = MeResponse`), nunca la ruta completa (`body = crate::me::service::MeResponse`). Con la ruta completa, utoipa 4.x genera un `$ref` literal roto (`crate.me.service.MeResponse`) que Swagger UI no puede resolver contra `components/schemas` (ahí sí se registra con el nombre corto). Esto obliga a `use` el tipo aunque solo se use dentro de la macro — como clippy lo marca `unused_imports`, esos `use` llevan `#[allow(unused_imports)]` encima (ver cualquier `controller.rs` como ejemplo).