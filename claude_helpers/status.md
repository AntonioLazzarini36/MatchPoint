# Estado del proyecto MatchPoint (con Claude Code)

> Documento vivo. Edítalo cuando quieras cambiar prioridades, tachar cosas o
> añadir contexto — lo uso como referencia al arrancar en otros chats.
> Última actualización: 2026-08-01.

## Contexto de branches

`dev` y `main` están muy desactualizados (siguen en el backend NestJS viejo,
sin el rewrite a Rust). La rama activa de verdad es **`feature/rust-backend`**
— trátala como el trunk real hasta que se decida cuándo/cómo mergear todo
esto en `dev`/`main`. Las branches de feature parten de ahí.

## Hecho

- **`fix/expose-age-not-birthdate`** — mergeada en `feature/rust-backend`.
  `/discover`, `/users/:userId/profile` y el lado `otherUser` de `/matches`
  devuelven `age` calculada en vez de `birthDate` exacto (PII innecesaria).
  `/me` y el lado `me` de `/matches` siguen con `birthDate` completo (tu
  propio dato).

- **`feat/logout-and-settings`** — mergeada en `feature/rust-backend`
  (2026-08-01) y pusheada. Logout real (borra token local + intenta revocar
  refresh token en backend, best-effort). Pantalla de Settings rediseñada
  siguiendo las mockups que pasaste (card de cabecera + fila de email +
  botón de cerrar sesión). Botones de "ajustes" y "ver mi perfil público" en
  `ProfileScreen` ahora funcionan. Trae además una regla nueva en
  `.gitignore` (`claude_helpers/*`) que ya cubre este documento y las
  mockups sin necesidad de gestionarlas a mano.

- **`feat/unmatch-block-report`** — mergeada en `feature/rust-backend`
  (commit `b115e88`, 2026-08-01) y pusheada. Checks en verde sobre el árbol
  mergeado (fmt/clippy/build/test backend, analyze/test mobile). Decisiones
  tomadas:
  - **Deshacer match** (`DELETE /matches/:matchId`): pide confirmación,
    borra el match y su chat. Además, esa persona **ya no vuelve a
    aparecer en Discovery** (se arregló que `/discover` no excluía a nadie
    ya swipeado — ahora excluye a quien ya diste LIKE o PASS, por deporte).
  - **Reportar** (`POST /users/:userId/report`): solo dice registro para
    revisión. **No borra el match ni corta el contacto** — si quieres
    cortar contacto, usas deshacer match, que es la única acción que hace
    eso.
  - **Bloquear se eliminó por completo** (backend, DB, UI) — se decidió que
    no aporta nada que deshacer-match + reportar no cubran ya en esta app.

- **`CLAUDE.md`** actualizado con una sección de autonomía: Claude no debe
  parar a pedir permiso a mitad de tarea (checks, Docker, decisiones de
  alcance/implementación) — solo se detiene justo antes de `git commit` /
  `git push` para que se revise el resultado.

- **`.claude/settings.json`** (commiteado, para todo el equipo) — allowlist
  de permisos para que `cargo fmt/clippy/build/test/run`, `flutter
  analyze/test/run/pub get`, `docker compose`, `diesel migration`, `curl` a
  localhost y los comandos git de solo lectura/locales (`status`, `diff`,
  `log`, `branch`, `checkout`, `merge`, `fetch`, `add`, `stash`, etc.) no
  interrumpan pidiendo aprobación, en línea con la sección de autonomía de
  `CLAUDE.md`. `git commit`, `git push` y las operaciones destructivas
  (`reset --hard`, `push --force`, `branch -D`, `clean -f`) están en la
  lista `ask`, no en `allow` ni en `deny` — siguen pidiendo confirmación
  siempre (nunca se auto-aprueban), pero sí se pueden aprobar cuando hace
  falta (a diferencia de `deny`, que las bloquearía sin remedio).

## Pendiente / próximos pasos

Branches ya creadas, sin empezar:

- **`redesign/ui-overhaul`** — rediseño general de la UI. Falta definir
  alcance/estilo (¿pantalla por pantalla con mockups como hicimos con
  Settings, o carta blanca?).
- **`test/full-app-suite`** — para que la persona que lea esto escriba sus
  propios tests (backend tiene prácticamente cero cobertura hoy — 1 solo
  test en todo `api-rust`).

Del análisis inicial completo del repo — **trabajado sin supervisión el
2026-08-01** mientras te ibas 3 horas. Los 9 puntos originales están
resueltos (uno de ellos reveló un bug de seguridad más serio, que se separó
en su propia rama). Cada uno en su propia rama, pusheada,
**SIN mergear a `feature/rust-backend`** a propósito para que los repases
y decidas el orden/forma de integrarlos:

1. ✅ **`fix/jwt-secret-required`** (commit `abb823c`) — Secretos JWT ya no
   tienen fallback hardcodeado; `JWT_ACCESS_SECRET`/`JWT_REFRESH_SECRET`
   ahora son obligatorios al arrancar (igual que `DATABASE_URL`). `.env`,
   `.env.example` y CI ya los definían, así que no rompe nada.
2. ✅ **`feat/auth-rate-limiting`** (commit `552a79d`) — Rate limiter en
   memoria por IP (10 req/60s, sin dependencia nueva) en
   `/auth/login|register|email-available`. Verificado a mano: request 11
   en adelante devuelve 429.
3. ✅ **`fix/profile-photos-validation`** (commit `da3b189`) — Se eliminó
   `photos` de `PATCH /me/profile` (backend y móvil) en vez de parchear con
   un límite: el móvil solo mandaba `[]` ahí de todos modos, las fotos de
   verdad siempre pasaron por `POST /me/photos`, que sí valida.
4. ✅ **`feat/discover-preferences-filter`** (commit `f67632d`) — `/discover`
   ahora filtra por `ageMin`/`ageMax` de `preferences` (traducido a rango de
   `birth_date` en la query SQL). **`distanceKm` y `genderPreference`
   siguen sin aplicarse** — no hay coordenadas guardadas ni campo de género
   en `Profile`, así que no hay con qué filtrar; eso es una feature más
   grande (migración + UI de onboarding), no la inventé. Verificado con
   datos reales del seed.
5. ✅ **`feat/mobile-refresh-token`** (commit `3d569fc`) — El móvil ya
   guarda y usa el refresh token. `ApiClient` intercepta cualquier 401 en
   una request autenticada, refresca en silencio vía `POST /auth/refresh`
   y reintenta una vez; los 401 concurrentes comparten el mismo refresh en
   vuelo (el backend rota el refresh token en cada uso, así que refrescos
   concurrentes sin coordinar se pisarían). Si el refresh token termina
   siendo rechazado, se limpian los tokens locales y el `redirect` de
   `router.dart` te manda solo a login en la siguiente navegación.
   **Bonus/hallazgo mientras probaba esto** → ver punto 5b.
5b. ✅ **`fix/refresh-token-rotation-bcrypt-truncation`** (commit `dad9f78`)
   — **Bug de seguridad real, no estaba en la lista original.** Probando
   5 descubrí que un refresh token "rotado" seguía funcionando después de
   rotar. Causa: bcrypt solo mira los primeros 72 bytes, y dos JWTs de
   refresh del mismo usuario comparten un prefijo idéntico bien más allá
   de eso (header + sub + email iguales; solo `exp`, cerca del final del
   payload, cambia) — bcrypt los trataba como el mismo token. En la
   práctica, la rotación no invalidaba nada. Fix: hashear con SHA-256 antes
   de pasarlo a bcrypt. **Nota:** esto invalida los `RefreshToken` ya
   guardados (hasheados con el esquema viejo) — cualquier sesión activa
   tendrá que volver a loguearse cuando su access token expire. Aceptable
   para una app en fase de desarrollo, no monté una migración para esto.
   Verificado end-to-end contra el backend real (login → rota → token
   viejo ahora 401, token nuevo 200, logout revoca correctamente).
6. ✅ **`fix/discovery-swipe-crash`** (commit `e5ce855`) — Dos bugs
   juntos: (a) al fallar un swipe por red, el rollback reinsertaba la
   carta con el mismo `Key(user.userId)` que el `Dismissible` que ya se
   había disparado — Flutter no tolera eso. (b) el `rethrow` del rollback
   nunca se capturaba (los callbacks de `onDismissed`/`onTap` no son
   `async`, así que la excepción quedaba sin manejar). Fix: un contador
   `generation` en el controller que cambia la key en cada rollback, +
   try/catch con SnackBar en los 3 puntos que disparan swipe (Dismissible,
   botón like, botón pass).
7. ✅ **`feat/chat-polling`** (commit `94fa09c`) — Sin montar un
   websocket (de más para la escala actual): el chat pollea cada 4s
   mientras está abierto, añade mensajes nuevos por id (sin duplicar),
   vuelve a marcar leído si llegó algo nuevo, y solo hace auto-scroll si
   ya estabas cerca del final.
8. ✅ **`fix/matches-real-unread-state`** (commit `191b483`) — `GET
   /matches` ahora devuelve `lastMessage` (texto desencriptado + emisor +
   fecha del último mensaje, `null` si no hay ninguno) y `unreadCount` real
   por match. También arreglé que `MatchesScreen` solo recargaba al volver
   del chat si hubo un unmatch — como entrar al chat marca leído
   (`ChatController.init` ya llamaba a `markRead`, pero la lista nunca se
   refrescaba), el badge de no-leído no se limpiaba nunca en el flujo
   normal. Verificado end-to-end entre dos cuentas del seed.
9. ✅ **TODOs sueltos** — de los 3 (`filtros discovery`, `super-like`,
   `buscador de matches`), solo hice el buscador
   (**`feat/matches-search`**, commit `f3bb6c3`): filtra la lista de
   conversaciones por nombre, client-side, sin tocar el backend. Los otros
   dos los dejé explícitamente sin tocar:
   - **Filtros de discovery**: no existe ninguna UI en el móvil para
     preferencias (ni el modelo siquiera) — construir esa pantalla a
     ciegas es el mismo riesgo que `redesign/ui-overhaul`.
   - **Super-like**: el propio comentario en el código dice que depende de
     una feature de backend que no existe (`SwipeType` solo tiene
     LIKE/PASS).

**10 ramas en total esta sesión**, todas pusheadas y verificadas
(fmt/clippy/build/test backend, analyze/test mobile, y pruebas manuales
contra el backend real donde aplicaba), ninguna mergeada a
`feature/rust-backend` todavía.

## Notas del entorno local

- La DB de dev en Docker (`matchpoint_db`) está mapeada al puerto **15432**,
  no el 5432 que asume `.env`/`docker-compose.yml`. Al levantar el backend a
  mano hace falta `DATABASE_URL` apuntando a `127.0.0.1:15432`.
- Cuentas de prueba: `cargo run --bin datagen` siembra 10 perfiles falsos,
  contraseña `password123` (p.ej. `javier.club@example.com`).
