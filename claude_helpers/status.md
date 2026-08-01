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

Del análisis inicial completo del repo, sin branch todavía (por prioridad,
de más a menos importante):

1. **Secretos JWT con fallback silencioso** a valores hardcodeados de dev si
   falta la env var en producción — riesgo de account takeover total.
2. **Rate limiting** en `/auth/login`, `/auth/register`,
   `/auth/email-available` (este último es oráculo de enumeración de
   emails).
3. **`PATCH /me/profile` deja sobrescribir `photos`** sin el límite de 6 ni
   validación que sí tiene `POST /me/photos`.
4. **`/discover` no usa `preferences`** — se guardan `ageMin`/`ageMax`/
   `distanceKm`/etc. pero nunca se filtran resultados con ellas.
5. **No hay refresh token en el móvil** — el backend lo soporta pero el
   cliente nunca lo guarda ni lo usa, así que cada sesión muere a los 15
   minutos sin recuperación.
6. **Crash de Discovery** si un swipe falla por red (`Dismissible` se
   reinserta con la misma key tras haberse disparado ya).
7. **Chat sin tiempo real** — solo carga mensajes una vez al entrar,
   sin polling ni websocket.
8. **Matches list con datos falsos** — "Nuevo match" y `unread: false`
   fijos para todo, no reflejan el estado real del chat.
9. Varios TODOs sueltos menores (filtros de discovery, super-like, buscador
   de matches).

## Notas del entorno local

- La DB de dev en Docker (`matchpoint_db`) está mapeada al puerto **15432**,
  no el 5432 que asume `.env`/`docker-compose.yml`. Al levantar el backend a
  mano hace falta `DATABASE_URL` apuntando a `127.0.0.1:15432`.
- Cuentas de prueba: `cargo run --bin datagen` siembra 10 perfiles falsos,
  contraseña `password123` (p.ej. `javier.club@example.com`).
