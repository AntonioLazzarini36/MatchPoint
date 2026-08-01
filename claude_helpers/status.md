# Estado del proyecto MatchPoint (con Claude Code)

> Documento vivo. Edítalo cuando quieras cambiar prioridades, tachar cosas o
> añadir contexto — lo uso como referencia al arrancar en otros chats.
> Última actualización: 2026-08-01.

## Contexto de branches

`dev` y `main` están muy desactualizados (siguen en el backend NestJS viejo,
sin el rewrite a Rust). La rama activa de verdad es **`feature/rust-backend`**
— trátala como el trunk real hasta que se decida cuándo/cómo mergear todo
esto en `dev`/`main`.

Ramas vivas ahora mismo, aparte del trunk:
- **`redesign/ui-overhaul`** — creada, sin empezar. Rediseño general de la
  UI. Falta definir alcance/estilo (¿pantalla por pantalla con mockups como
  hicimos con Settings, o carta blanca?).
- **`test/full-app-suite`** — creada, sin empezar. Reservada para que la
  persona que lea esto escriba sus propios tests (cobertura hoy: 1 test de
  crypto en el backend, 1 widget test boilerplate en mobile — prácticamente
  cero).

Todo lo demás de ramas anteriores (`fix/expose-age-not-birthdate`,
`feat/logout-and-settings`, `feat/unmatch-block-report`, y las 10 de la
pasada de seguridad/fiabilidad del 2026-08-01) ya está **mergeado en
`feature/rust-backend` y las ramas borradas** (local y remoto) — el detalle
de cada una vive en el historial de git (`git log feature/rust-backend`),
no hace falta duplicarlo aquí.

## Hecho (resumen)

- Migración completa NestJS → Rust (`services/api-rust`), Swagger/OpenAPI,
  generador de datos de prueba (`datagen`).
- Privacidad: `/discover`, `/users/:userId/profile` y el lado `otherUser`
  de `/matches` devuelven `age` calculada, nunca `birthDate` exacto.
- Logout real + pantalla de Settings (con botón de volver, arreglado
  2026-08-01 — no tenía `AppBar`).
- Deshacer match (`DELETE /matches/:matchId`) + Reportar
  (`POST /users/:userId/report`, no corta contacto) — Bloquear se eliminó
  por completo (backend+DB+UI), se decidió que unmatch+report ya cubre lo
  que haría.
- **Pasada de seguridad/fiabilidad completa (2026-08-01)**, 10 ramas, todas
  verificadas (fmt/clippy/build/test backend, analyze/test mobile, y
  pruebas manuales contra el backend real) y ya mergeadas:
  - JWT: secretos obligatorios al arrancar, sin fallback hardcodeado.
  - Rate limiting (10 req/60s por IP) en `/auth/login|register|email-available`.
  - `PATCH /me/profile` ya no acepta `photos` (bypaseaba validación/límite).
  - `/discover` filtra por `ageMin`/`ageMax` reales de `preferences`
    (`distanceKm`/`genderPreference` siguen sin aplicarse — no hay
    coordenadas ni campo de género guardados).
  - Refresh token real en el móvil (guardado, auto-refresh en 401,
    reintento, manejo de refrescos concurrentes).
  - 🔴 **Bug de seguridad no listado, encontrado al probar lo anterior:**
    bcrypt trunca a 72 bytes y dos refresh tokens del mismo usuario
    comparten prefijo más allá de eso → la rotación de refresh token no
    invalidaba nada en la práctica. Arreglado (SHA-256 antes de bcrypt).
    Invalida sesiones viejas (hash de formato distinto) — toca re-loguearse
    una vez.
  - Fix de crash real en Discovery (swipe fallido por red + reinserción de
    `Dismissible` con key repetida).
  - Chat con polling (4s) en vez de solo cargar una vez.
  - Matches: `unreadCount`/`lastMessage` reales (antes "Nuevo match" y
    `unread: false` fijos para todo); recarga real al volver del chat.
  - Buscador de matches por nombre (client-side).
- Documentación: `CLAUDE.md`, `README.md`, `services/api-rust/NOTES.md`
  puestos al día (endpoints que faltaban desde antes: unmatch, report;
  `services/api` viejo ya no existe, etc.) el 2026-08-01.
- `.claude/settings.json` (commiteado, equipo entero): allowlist de
  permisos para que builds/tests/docker/git-local no interrumpan pidiendo
  aprobación — solo `git commit`/`push`/ops destructivas piden confirmación
  siempre (nunca se auto-aprueban, pero se pueden aprobar).

## Pendiente / próximos pasos

### Sin empezar, esperando tu decisión
- **`redesign/ui-overhaul`** — falta definir alcance/estilo.
- **`test/full-app-suite`** — para que la escribas vos.
- **UI de preferencias de Discovery** (filtros de edad/distancia/deporte):
  no existe ninguna pantalla ni modelo en el móvil para esto. El backend ya
  filtra por edad (`/discover`), pero no hay forma de cambiarla desde la
  app fuera del registro. Necesita diseño, no lo inventé.
- **Sistema de rating/nivel** (Elo vs Glicko-2): pieza central del
  producto para emparejar por nivel, sin diseñar todavía — ni tabla, ni
  cómo lo usaría `discover`.
- **Distancia real**: necesita guardar coordenadas (migración de schema) +
  UI de ubicación en onboarding. Sin eso, `distanceKm` en preferencias no
  tiene con qué compararse.
- **Campo de género**: `Preferences.genderPreference` existe pero
  `Profile` no tiene ningún campo de género que filtrar — mismo problema
  que distancia, necesita schema + UI.
- **Super-like**: el propio TODO en el código dice que depende de una
  feature de backend que no existe (`SwipeType` solo tiene LIKE/PASS).

### Del análisis fresco de hoy (2026-08-01), sin rama todavía

Seguridad/fiabilidad, por prioridad:

1. **Validación de fotos por content-type del cliente, no por contenido
   real** (`me/photos.rs::extension_for`) — confía en el header
   `Content-Type` que manda el cliente para decidir la extensión
   (`jpg`/`png`/`webp`), nunca mira los bytes reales del archivo. Alguien
   puede subir cualquier cosa etiquetada como imagen. Fix: sniffear los
   magic bytes reales (crate tipo `infer`) y rechazar si no coincide con
   lo declarado.
2. **Sin rate limit en endpoints autenticados de por sí "caros" o
   abusables**: `/swipes`, `POST /me/photos`, `POST /users/:userId/report`,
   `POST /chats/:matchId/messages`. Un usuario autenticado normal podría
   spammear cualquiera de estos sin límite (a diferencia de los endpoints
   de auth, que sí están cubiertos desde hoy).
3. **`GET /health` no comprueba la DB** — solo devuelve `{ok:true}` fijo;
   la conectividad a Postgres solo se chequea una vez, al arrancar. Un
   liveness probe (k8s/load balancer) contra `/health` no detectaría una
   caída de la base de datos en caliente.
4. **CORS totalmente abierto** (`allow_origin/methods/headers(Any)`) —-
   razonable en dev, y el riesgo real es bajo porque la auth es Bearer
   token (no cookies, así que CORS abierto no expone el token a otros
   orígenes), pero vale la pena cerrarlo antes de cualquier despliegue
   real.
5. El rate limiter de auth usa `ConnectInfo` (IP de la conexión TCP
   directa) — si esto algún día corre detrás de un proxy/load balancer,
   vería la IP del proxy para todo el mundo y el límite dejaría de ser
   por-cliente. Ya está anotado en el código (`rate_limit.rs`), pero
   recordatorio para cuando se hable de despliegue real.

Nada de esto lo toqué sin preguntar — son hallazgos, no cambios.

## Notas del entorno local

- La DB de dev en Docker (`matchpoint_db`) está mapeada al puerto **15432**,
  no el 5432 que asume `.env`/`docker-compose.yml`. Al levantar el backend a
  mano hace falta `DATABASE_URL` apuntando a `127.0.0.1:15432`.
- Cuentas de prueba: `cargo run --bin datagen` siembra 10 perfiles falsos,
  contraseña `password123` (p.ej. `javier.club@example.com`).
