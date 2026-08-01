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
- **`feat/tennis-court-map`** — ✅ mergeada en `feature/rust-backend`
  (2026-08-01), **probada por vos en el navegador y ajustada varias veces**
  en base a tu feedback en vivo (ver "Hecho" abajo para el detalle de cada
  ajuste). **Rama dejada viva a propósito** (no borrada como las demás) —
  dijiste que es probable que pidas más cambios sobre el mapa a futuro, así
  que sigue existiendo en local y remoto para seguir iterando ahí en vez de
  abrir una rama nueva.

Todo lo demás de ramas anteriores (`fix/expose-age-not-birthdate`,
`feat/logout-and-settings`, `feat/unmatch-block-report`, `feat/manual-location`,
`fix/discovery-header-cleanup`, y las 10 de la pasada de seguridad/fiabilidad
del 2026-08-01) ya está **mergeado en `feature/rust-backend` y las ramas
borradas** (local y remoto) — el detalle de cada una vive en el historial de
git (`git log feature/rust-backend`),
no hace falta duplicarlo aquí.

### Issues de GitHub — correlación con lo de arriba

Vi la lista de issues abiertos del repo mientras trabajaba en esto (no toqué
GitHub, solo lo apunto para cuando quieras cerrarlos/asignarlos):
- **#15 "Corregir que no se muestren perfiles que ya son matches"** — creo
  que esto **ya está resuelto** desde `feat/unmatch-block-report` (ya
  mergeada): `/discover` excluye a cualquiera a quien ya le diste LIKE o
  PASS, y un match requiere que ambos se hayan dado LIKE, así que un
  perfil ya matcheado no puede reaparecer. Vale la pena que lo confirmes
  probando y cierres el issue si es así.
- **#18 "Mapa de pistas + reservar"** — `feat/tennis-court-map` cubre la
  primera mitad (ver pistas reales, proponer partido a un match). La
  reserva de verdad (disponibilidad, booking) no está — es harina de otro
  costal, tal como dijiste.
- **#17 "Sistema de ratings"**, **#19/#12 "Calendario"**, **#14 "Edit
  profile en Settings"**, **#16 "Rediseño"** — ninguno tocado, siguen
  abiertos. Ver la lista priorizada más abajo.
- **#11 "Brainstorming doc"**, **"Create DataFlow diagram"** — documentación
  pura, no código; no los toqué.

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
- **Ubicación estilo Hinge (`feat/manual-location`, ✅ mergeada)** — nada
  de GPS: escribes un sitio (ciudad, barrio, pueblo — "Málaga",
  "Benalmádena", "Innsbruck") y eliges de sugerencias reales (Nominatim,
  geocoding gratis de OSM, sin API key), igual que Hinge. Esa elección es
  la que usa `/discover` para el filtro de radio, y se puede cambiar en
  cualquier momento desde Settings, no solo en el onboarding. Backend:
  migración `Profile.latitude/longitude` (nullable — `city` se reutiliza
  como el nombre mostrado del sitio elegido, no hizo falta columna nueva),
  `/discover` filtra por distancia real (Haversine en Rust, sin
  PostGIS/earthdistance instalado) contra `preferences.distanceKm`; ni
  viewer ni candidato sin coordenadas se ven afectados por el filtro (para
  no vaciar discover mientras no todo el mundo haya puesto ubicación).
  Coordenadas nunca salen al público (mismo criterio que `birthDate`→
  `age`). `datagen` ahora pone coordenadas reales a los 10 perfiles falsos
  (ya eran pueblos de la Costa del Sol). Sin enum de localidades — el
  buscador escala a cualquier sitio del mundo. Verificado con checks +
  curl contra el backend real (radio de 10km desde Málaga excluye
  Fuengirola/Mijas, 50km los incluye) + `flutter build web --release`
  limpio.
- **Limpieza del header de Discovery (`fix/discovery-header-cleanup`, ✅
  mergeada)** — se quitó el toggle "Tenis"/"Correr" y una fila
  "Partner"/"Match" que no hacía nada (`isPartnerMode` se guardaba pero
  nunca se leía en ningún lado). Discovery ahora es un único feed
  implícito (tenis por defecto, igual que antes) con solo un título y el
  ícono de filtros (todavía inerte, pendiente de la UI de preferencias de
  arriba). Se borraron los dos widgets ya sin uso.
- **Mapa de clubes de tenis, MVP (`feat/tennis-court-map`, ✅ mergeada,
  probada en vivo por vos y ajustada en varias vueltas)** — a propósito
  acotado ("poco a poco"): `flutter_map` + tiles de OSM (sin API key),
  clubes reales cerca vía Overpass API. Reutiliza `MatchesService`/
  `ChatService` tal cual, sin endpoint ni modelo de datos nuevo para
  "propuestas" — esa es la frontera del MVP. Entrada: ícono en la AppBar
  de Matches, no una 5ª pestaña del bottom nav. Sin reservas/
  disponibilidad real — eso es el issue #18 completo, mucho más grande.
  Ajustes hechos tras probarlo en el navegador:
  - El mapa arranca en tu ubicación de perfil (`feat/manual-location`), no
    en Madrid fijo — Madrid solo como fallback si tu cuenta no tiene
    ubicación seteada todavía.
  - OSM casi no tiene datos con la etiqueta real de "club"
    (`leisure=sports_centre`+`sport=tennis` → 0 resultados cerca de
    Madrid, comprobado). Las pistas sueltas (`leisure=pitch`) sí están
    bien mapeadas y las de un mismo club quedan físicamente juntas, así
    que ahora se agrupan por cercanía (150m) en clusters mostrados como
    "club" con conteo de pistas.
  - `overpass-api.de` (la instancia pública principal) devolvió 504
    Gateway Timeout probándolo en vivo — se agregó fallback a un segundo
    espejo confirmado (`maps.mail.ru`) + botón de "Reintentar" visible.
    Se descartó a propósito `overpass.osm.ch` pese a responder rápido:
    devuelve 0 resultados para queries con datos reales, peor que un
    timeout honesto.
  - El link que se manda es de Google Maps (búsqueda por coordenadas,
    siempre funciona), no de OpenStreetMap (que "no mostraba nada" según
    feedback en vivo) — si el club tiene `website` en OSM se agrega como
    extra (raro: 0/40 cerca de Madrid lo tenían).
  - Selector de día: calendario semanal navegable de verdad
    (lunes-domingo en fila, `<`/`>` para cambiar de semana), no una lista
    plana de "próximos 7 días" sin poder avanzar — no se puede ir a
    semanas anteriores a la actual.
  - Selector de hora: franjas de 15 min de 8:00 a 22:00 en grilla, con
    columnas que se recalculan según el ancho de pantalla disponible
    (`SliverGridDelegateWithMaxCrossAxisExtent`) en vez de un número fijo
    que en pantalla chica achicaba los botones hasta que la hora dejaba
    de verse.
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
- ~~**Distancia real**~~ — resuelto en `feat/manual-location` (ver
  "Hecho"), pendiente de que la revises y mergees.
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
