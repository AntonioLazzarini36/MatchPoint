# Estado del proyecto MatchPoint (con Claude Code)

> Documento vivo. Edítalo cuando quieras cambiar prioridades, tachar cosas o
> añadir contexto — lo uso como referencia al arrancar en otros chats.
> Última actualización: 2026-08-02.

## Contexto de branches

`dev` y `main` están muy desactualizados (siguen en el backend NestJS viejo,
sin el rewrite a Rust). La rama activa de verdad es **`feature/rust-backend`**
— trátala como el trunk real hasta que se decida cuándo/cómo mergear todo
esto en `dev`/`main`.

Ramas vivas ahora mismo, aparte del trunk:
- **`fix/discovery-sports-selection`** — ✅ hecha, verificada
  (analyze/test en verde, probada en vivo en Chrome), **pusheada a
  origin, todavía sin mergear** en `feature/rust-backend` (se dejó así a
  propósito — solo se pidió commit+push, el merge queda para cuando lo
  decidas). Arregla el bug real de status.md: `DiscoveryController`
  estaba fijo en `Sport.tennis` sin importar qué eligió el usuario en el
  onboarding — quien elegía solo "Correr" nunca veía a nadie. Ahora el
  feed se arma por cada deporte del propio perfil y se unen los
  resultados; agrega también una fila "Deportes" en Settings (antes no
  existía forma de cambiar tus deportes después del onboarding).
- **`feat/skill-level-and-credentials`** — ✅ hecha, verificada
  (fmt/clippy/build/test backend, analyze/test mobile, probada en vivo en
  Chrome), **pusheada a origin, sin mergear** en `feature/rust-backend`
  (igual que la de arriba, mergeo pendiente de tu decisión). Ver "Hecho"
  y "Reposicionamiento de producto" más abajo para el detalle completo —
  nivel auto-declarado por deporte + credenciales (años jugando, club,
  logros) + banner de bienvenida en Discovery.
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
- **Rama de login social (Google/Apple) + verificación de identidad** —
  pedida el 2026-08-01, **sin empezar, sin crear todavía** (solo
  documentada, ver "Pendiente" abajo) — necesita que decidas/consigas
  credenciales externas antes de que tenga sentido escribir código real.
- **Rama de fix de deportes + editar deporte en perfil** — pedida el
  2026-08-01, **sin empezar, sin crear todavía** (solo documentada, ver
  "Pendiente" abajo) — encontré un bug real relacionado al investigar esto,
  detalle abajo.

Todo lo demás de ramas anteriores (`fix/expose-age-not-birthdate`,
`feat/logout-and-settings`, `feat/unmatch-block-report`, `feat/manual-location`,
`fix/discovery-header-cleanup`, `redesign/discovery-cards`, y las 10 de la
pasada de seguridad/fiabilidad del 2026-08-01) ya está **mergeado en
`feature/rust-backend` y las ramas borradas** (local y remoto) — el detalle
de cada una vive en el historial de git (`git log feature/rust-backend`),
no hace falta duplicarlo aquí.

⚠️ **Ramas locales viejas sin documentar, no tocadas:** `gonzalo` y
`restore-7a0d958` (local), más `origin/12-calendar` (remoto) — son de antes
del rewrite a Rust (commits tipo "fix prisma chat flow", "npm run lint
--fix"), de la era NestJS/Prisma. No forman parte del trabajo activo en
`feature/rust-backend`; las dejo intactas por si son tuyas o de un
colaborador (el nombre "gonzalo" sugiere que sí) — decime si querés que las
borre o si hay algo ahí que rescatar antes de irse del todo.

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
- **`fix/discovery-sports-selection` (2026-08-02, ✅ commiteada y
  pusheada, sin mergear)** — `DiscoveryController` respeta ahora los
  deportes reales del usuario (antes fijo en tenis); fila "Deportes" en
  Settings para poder cambiarlos después del onboarding.
- **Nivel auto-declarado + credenciales, `feat/skill-level-and-credentials`
  (2026-08-02, ✅ commiteada y pusheada, sin mergear)** — primera mitad
  del "Reposicionamiento de producto" de abajo. Backend: tabla nueva
  `SkillLevel` (una fila por `userId`+`sport`, enum
  `BEGINNER/INTERMEDIATE/ADVANCED/COMPETITIVE`, no ligado a `Profile`
  porque el nivel es por deporte, no global) + columnas
  `yearsPlaying`/`club`/`achievements` en `Profile`. Nuevo
  `PATCH /me/skill-levels` (upsert por deporte, no toca los que no vienen
  en el body); `PATCH /me/profile` extendido con las credenciales.
  Expuesto en `/me`, `/discover`, `/users/:userId/profile` y el lado
  `otherUser` de `/matches` — mismo nivel de visibilidad que `bio`/
  `sports` (público, no tan privado como `birthDate`). `datagen` siembra
  nivel+credenciales realistas por perfil falso (Diego "competitivo,
  club, 2 logros", Andrea "principiante", etc.) para tener datos reales
  al probar. Móvil: paso nuevo de onboarding ("Tu nivel", entre Perfil y
  Objetivo — chips de nivel por deporte + años/club/logros, todo
  opcional, no bloquea "Siguiente"); filas "Nivel"/"Credenciales" en
  Settings (mismo patrón que Ubicación/Radio); badge de nivel en la
  esquina de la mini-card de Discovery, sección "Experiencia" en el
  preview sheet y en `ProfileView` (compartida entre perfil propio y
  perfil público de otros). Además, banner de bienvenida de Discovery
  ("Encontrá tu compañero de juego..."), mostrado una sola vez (flag en
  `flutter_secure_storage`, no un paquete nuevo) — ver
  "Reposicionamiento de producto" más abajo, punto 3. Verificado:
  fmt/clippy/build/test backend en verde, migración corrida contra la DB
  real, curl end-to-end (`/me`, `/discover`, `PATCH /me/skill-levels`)
  con datos reales; analyze/test mobile en verde; probado en vivo en
  Chrome (onboarding hasta el paso de fotos, Settings con datos reales de
  Diego, Discovery con badges de nivel y preview con Experiencia).
  **Deliberadamente no tocado en esta rama**: el mecanismo de swipe y el
  lenguaje "Match"/corazón (punto 4 del reposicionamiento) — se solapa
  con `redesign/ui-overhaul`, sin alcance definido, así que hacerlo a
  ciegas hubiera sido tirar trabajo.
- **Pulido de onboarding tras feedback en vivo (2026-08-02, misma rama
  `feat/skill-level-and-credentials`)** — probaste el paso de deportes y
  volviste con cuatro pedidos concretos, todos hechos:
  - El paso de "Tu perfil" arrancaba con Tenis **y** Correr ya marcados
    los dos, así que tocar un chip lo *sacaba* — se leía como "estoy
    borrando algo", no "estoy eligiendo". Ahora arranca sin nada
    marcado (`OnboardingProfileScreen._selectedSports = {}`), valida
    que elijas al menos uno antes de "Siguiente", y el chip de deporte
    se rediseñó como tarjeta grande (ícono + check + fondo sólido
    `primary` cuando está seleccionado, borde neutro si no) en vez del
    `FilterChip` chico de antes — mucho más difícil de leer mal.
  - Las credenciales ahora dependen del deporte: si jugás al tenis ves
    años jugando + club (como antes); si corrés ves ritmo medio
    (min/km) y distancia media (km) en su lugar; si jugás ambos, ves
    los cuatro campos. Logros/torneos es compartido, sea cual sea el
    deporte. Nuevas columnas `Profile.avgPaceMinPerKm`/`avgDistanceKm`
    (mismo patrón que `yearsPlaying`/`club`: nullable, expuestas en
    `/me`/`/discover`/`/users/:userId/profile`/`otherUser` de
    `/matches`). Mismo patrón condicional en el paso de onboarding y en
    la fila "Credenciales" de Settings.
  - "Credenciales (opcional)" se sacó del texto — en vez de escribirlo,
    el botón del wizard dice "Saltar" mientras no hayas tocado nada en
    ese paso (ni nivel, ni ningún campo de credenciales) y pasa solo a
    "Siguiente" en cuanto cargás algo. Autoexplicativo, sin texto extra.
  - El recuadro "Elegir ubicación" del onboarding ahora muestra un mapa
    chico (`flutter_map`, mismo patrón que el mapa de clubes) con un
    pin en el sitio elegido, una vez que elegís uno — sin círculo de
    radio, se descartó a propósito por ser complejidad extra para poco
    beneficio visual a ese tamaño.
  - De paso, más texto explicando el "para qué" en varios pasos del
    wizard (perfil, deportes, ubicación) — no solo en el paso de
    deportes que motivó el pedido.
  Verificado: fmt/clippy/build/test backend en verde, migración corrida,
  curl end-to-end contra `/me` con datos reales de ritmo/distancia;
  analyze/test mobile en verde. Sin prueba visual en vivo esta vuelta —
  la extensión de Chrome no estaba conectada en el momento; vos ibas a
  probarlo de todos modos.
- **Dos bugs reales de esa prueba en vivo (2026-08-02, misma rama),
  arreglados:**
  - **Mapa del paso de ubicación no se recentraba.** Al elegir una
    ubicación nueva, el pin se movía a las coordenadas correctas pero
    la cámara del mapa se quedaba en el sitio anterior — el pin quedaba
    fuera de la vista, así que se veía "el mapa de antes, sin pin".
    Causa: `flutter_map`'s `MapOptions.initialCenter` solo se aplica al
    montar el widget la primera vez, no en cada rebuild; sin nada que
    lo forzara a remontar, la cámara nunca se movía tras el primer
    render. Arreglado dándole al `FlutterMap` una `key` atada a las
    coordenadas (`onboarding_location_step.dart`) — al cambiar la
    ubicación, cambia la key, y Flutter remonta el mapa entero, que
    vuelve a centrar solo.
  - **Los campos de ritmo/distancia/años/club "saltaban" de campo
    mientras escribías, y no dejaban escribir ":" en el ritmo.** Causa
    de fondo: `OnboardingSkillStep` usaba
    `TextFormField(initialValue: ..., key: ValueKey('campo-$valor'))`
    — como `$valor` es justo el valor que se actualiza en cada
    pulsación (vía `onChanged` → `setState` en el padre), la `key`
    cambiaba en cada tecla, así que Flutter destruía y recreaba el
    campo en cada pulsación: perdía el foco a mitad de escribir y (en
    web) el navegador lo movía al siguiente campo enfocable. Arreglado
    convirtiendo `OnboardingSkillStep` a `StatefulWidget` con
    `TextEditingController`s creados una sola vez en `initState`, sin
    key dependiente del valor — mismo patrón que ya usaba
    correctamente `_CredentialsSheet` en Settings (por eso ese no tenía
    el bug). De paso, el ritmo ahora se escribe y se muestra como
    "min:seg" (`4:30`) en vez de decimal (`4.5`), que es como la gente
    que corre piensa su ritmo de verdad — nuevo helper compartido
    `core/utils/pace_format.dart` (`parsePaceMinPerKm`/
    `formatPaceMinPerKm`, acepta también decimal por si acaso) usado en
    onboarding, Settings, preview de Discovery y `ProfileView`. El
    dato en el backend no cambió — sigue siendo minutos decimales
    (`Profile.avgPaceMinPerKm`), el formato "min:seg" es solo cosa del
    cliente.
  Verificado: analyze/test mobile en verde.

## Pendiente / próximos pasos

### Sin empezar, esperando tu decisión
- **`redesign/ui-overhaul`** — falta definir alcance/estilo.
- **`test/full-app-suite`** — para que la escribas vos.
- **UI de preferencias de Discovery** (filtros de edad/distancia/deporte):
  no existe ninguna pantalla ni modelo en el móvil para esto. El backend ya
  filtra por edad (`/discover`), pero no hay forma de cambiarla desde la
  app fuera del registro. Necesita diseño, no lo inventé.
- **Rating calculado** (Elo vs Glicko-2), a partir de resultados de
  partidos reales — el nivel *auto-declarado* por deporte ya existe
  (`feat/skill-level-and-credentials`, ver "Hecho"), esto es la parte
  larga/pendiente: no hay ningún flujo para cargar el resultado de un
  partido jugado, ni tabla para guardarlo, ni cómo lo usaría `discover`
  para emparejar.
- ~~**Distancia real**~~ — resuelto en `feat/manual-location` (ver
  "Hecho"), pendiente de que la revises y mergees.
- **Campo de género**: `Preferences.genderPreference` existe pero
  `Profile` no tiene ningún campo de género que filtrar — mismo problema
  que distancia, necesita schema + UI.
- **Super-like**: el propio TODO en el código dice que depende de una
  feature de backend que no existe (`SwipeType` solo tiene LIKE/PASS).

### Pedidas el 2026-08-01, todavía sin empezar (documentadas para no perderlas)

**1. Login con Google/Apple + verificación de identidad (email u otra)**

Objetivo: poder registrarte/loguearte con Google o Apple y que el perfil se
cree directo con esos datos, más algún tipo de confirmación de que el
usuario es quien dice ser (verificación de email como mínimo).

Por qué no arranqué esta directamente:
- **OAuth real necesita credenciales externas que no tengo**: un Client ID
  de Google Cloud Console (OAuth consent screen configurado) y, para Apple,
  un Apple Developer account con el "Sign in with Apple" capability
  habilitado + las claves de firma. Sin eso no hay nada real que probar —
  puedo dejar el código armado (paquetes `google_sign_in` /
  `sign_in_with_apple`, endpoint de backend que verifica el ID token
  contra Google/Apple y crea o loguea al `User`), pero hace falta que
  crees esas credenciales vos (son cuentas/proyectos tuyos) antes de que
  esto funcione de verdad en vez de ser un mock.
- **Verificación de email tampoco existe hoy en absoluto** — ahora mismo
  cualquiera se registra con cualquier email sin confirmar que le
  pertenece. Implementarla de verdad necesita un servicio de envío de
  email (SendGrid, SES, Resend, lo que prefieras) con sus propias
  credenciales — mismo problema de "necesito que decidas/consigas algo
  externo" antes de escribir el código real.

Qué implicaría en el modelo de datos: `User.password_hash` tendría que
pasar a ser opcional (cuentas 100% OAuth no tienen password), agregar algo
tipo `authProvider`/`providerId` para trackear con qué te registraste, y
`emailVerifiedAt` (o similar) para el estado de verificación.

Cuando quieras arrancar esto en serio, decime qué proveedor de email
preferís (o si ya tenés cuenta en alguno) y si ya tenés (o vas a crear) el
proyecto de Google Cloud / cuenta de Apple Developer — así no invento
credenciales que después hay que tirar.

**2. Bug de deportes en Discovery + poder editar tu(s) deporte(s) desde el perfil**

Me pediste comprobar si hay un problema al seleccionar Tenis y Correr a la
vez en el onboarding. **La selección en sí no tiene bug** — es un
`FilterChip` normal, ambos se pueden marcar juntos, y el backend guarda
bien un array con los dos (`Profile.sports: Vec<Sport>`).

**Pero sí encontré un bug real, más grave de lo que preguntaste, en
`fix/discovery-header-cleanup`** (ya mergeada): al sacar el selector de
deporte de arriba de Discovery, `DiscoveryController.selectedSport` quedó
**fijo en `Sport.tennis`** (`discovery_controller.dart`). Consecuencia:
- Si elegiste **solo "Correr"** en el onboarding, Discovery nunca te
  muestra a nadie — siempre pide `sport=TENNIS` al backend, nunca
  `RUNNING`.
- Si elegiste **ambos**, da igual: nunca vas a ver a nadie marcado solo
  como "Correr", ni vas a aparecerle a nadie que busque solo running —
  Discovery ignora completamente tu propia selección de deportes y la
  de cualquier otro, siempre opera en modo "solo tenis".
- No hay forma de cambiar tu(s) deporte(s) después del onboarding — ni en
  Settings ni en ningún otro lado. Esto no es "puede que exista", **no
  existe**, confirmado.

Cuando se arranque esta rama, el fix real no es "volver a poner el
toggle arriba de Discovery" (eso es justo lo que se sacó a propósito por
no tener sentido visualmente) — hay que decidir algo tipo: Discovery
respeta los deportes que el usuario tiene marcados en su perfil (podría
buscar en varios deportes a la vez, no solo uno), y separado, agregar una
fila "Deportes" en Settings (mismo patrón que Ubicación/Radio) para poder
cambiarlos. Backend no necesita cambios — `PATCH /me/profile` ya acepta
`sports`.

**3. Rediseño de Discovery a tarjetas horizontales — ✅ construida, probada
en vivo por vos en Chrome, ajustada, y ya mergeada en `feature/rust-backend`
(2026-08-01). `redesign/discovery-cards` borrada (local y remoto).**

Qué se pidió: cambiar el deck de una tarjeta a la vez por hasta 4 tarjetas
chicas de forma horizontal (rectángulo ancho, no cuadrado), cada una
arrastrable a los lados para dar like/pass, con preview al tocar, sin
botones de like/pass, y con un overlay difuminado direccional mientras
arrastrás.

El diseño pasó por 3 vueltas en vivo contigo antes de mergear — la primera
interpretación ("horizontal" = fila lado a lado) y luego un deck superpuesto
no eran lo que querías; el diseño final es:
- Columna vertical de hasta 4 tarjetas, **sin superponerse**, con margen a
  los lados/arriba/abajo (no tocan el borde de la pantalla ni el nav de
  abajo).
- Cada tarjeta tiene **altura fija** (`LayoutBuilder` calcula 1/4 del alto
  disponible una sola vez, dividiendo por el máximo de 4) — el tamaño no
  cambia según cuántas tarjetas queden; solo cambia cuántas filas hay
  (posición), nunca el tamaño de cada una.
- Al swipear una, las de abajo simplemente se recalculan solas (menos
  filas) — no hizo falta lógica de "pop-in" explícita, sale gratis de usar
  el `stack` plano del controller tal cual estaba.

Qué se construyó, archivo por archivo:
- `discovery_controller.dart` — se sacó `top` (ya no existe "la de arriba",
  cualquier tarjeta visible es swipeable) y `likeTop()`/`passTop()` (código
  muerto sin los botones). `swipeUser()` no cambió — ya operaba por
  `userId`, no por posición, así que sirve igual para la columna.
- `discovery_mini_card.dart` (nuevo) — tarjeta compacta: foto, gradiente
  oscuro abajo, nombre + edad. Sin más info (para eso está el preview).
- `discovery_preview_sheet.dart` (nuevo) — bottom sheet
  (`DraggableScrollableSheet`) con foto grande, nombre, edad, ciudad,
  chips de deportes y bio. Se abre al tocar una tarjeta. Deliberadamente
  un modal y no una navegación a otra pantalla — así no perdés tu lugar en
  la columna de debajo. Reemplaza el viejo comportamiento de
  `onOpenProfile` que navegaba a `AppRoutes.userProfileName`.
- `discovery_screen.dart` — reescrita. `_buildBody` arma un `Column` con
  `LayoutBuilder` (altura fija por tarjeta, ver arriba) donde cada tarjeta
  es un `Dismissible` individual (mismo patrón `generation`-keyed que ya
  existía para evitar el crash de Flutter al hacer rollback de un swipe
  fallido). Se sacaron los botones de like/pass (`_buildActions`) y el
  `DiscoveryActionButton` que solo ellos usaban.
- `discovery_action_button.dart` y `discovery_swipe_card.dart` — borrados
  (código muerto tras sacar los botones y la tarjeta grande).

Decisiones que tomé porque las dejaste abiertas ("ya sea A o B", "corazón
o pulgar o raqueta"):
- Iconos del overlay: mantuve corazón (like, derecha, verde) y X (pass,
  izquierda, roja) — son los que ya usaba el resto de la app, no metí la
  raqueta para no introducir un ícono nuevo sin necesidad.
- El overlay es un color wash traslúcido sobre toda la tarjeta (no un
  badge chico) porque a este tamaño de tarjeta un badge no se lee bien.

Verificado: `flutter analyze`/`flutter test` en verde en cada vuelta, y
probado en vivo por vos corriendo `flutter run -d chrome` contra el backend
real (con la DB y `cargo run` ya levantados). Mergeado con `--no-ff` en
`feature/rust-backend` (commit `62f9bdb`), sin conflictos.

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

### Ideas nuevas para el backlog (mías, no pedidas — 2026-08-02)

Cosas que noté mientras trabajaba en lo de arriba y que no estaban
anotadas en ningún lado. Ninguna la empecé — son solo ideas para cuando
quieras priorizar:

1. **Con el rediseño de Discovery, el feed no se re-pide solo cuando
   quedan pocas tarjetas.** `reload()` solo se llama a mano ("Reiniciar
   búsqueda") cuando el stack llega a 0. Con el deck viejo (una tarjeta a
   la vez) no se notaba, pero con la columna de hasta 4 huecos fijos,
   bajar a 1-2 perfiles deja 2-3 espacios vacíos visibles antes de llegar
   al estado "No hay más perfiles cerca". Podría auto-refetch cuando el
   stack baja de cierto umbral (ej. <4) en vez de solo al vaciarse del
   todo.
2. **No hay "deshacer último swipe"** (para un pass sin querer) — común en
   apps similares, no existe ni en el backend ni en la UI.
3. **No hay borrar cuenta.** Existe logout, deshacer match y reportar,
   pero ningún endpoint tipo `DELETE /me` ni UI para borrar la cuenta del
   todo — hueco en el ciclo de privacidad si en algún momento importa
   cumplimiento tipo RGPD.
4. **No se puede reordenar fotos ni elegir cuál es la principal** —
   `DiscoverProfile.mainPhoto` es siempre `photos.first`, o sea "la
   primera que subiste", sin forma de cambiarla después sin borrar y
   resubir en el orden que querés.
5. **Sin notificaciones push.** El chat usa polling (4s) mientras estás
   en esa pantalla, pero no hay nada si la app está en segundo plano o en
   otra pantalla — te enterás de un match/mensaje nuevo solo si volvés a
   abrir la pestaña correspondiente.

## Reposicionamiento de producto (pedido el 2026-08-02)

Conversación con vos sobre hacia dónde va MatchPoint, resumida acá porque
cambia cómo hay que pensar features futuras — no es un detalle de una
rama, es el marco general.

**Lo que dijiste:** MatchPoint no es (o no debería sentirse como) una app
de citas que usa el deporte de excusa. Es una app para que alguien que
juega al tenis (o corre, o cualquier deporte de a dos) encuentre a otra
persona **de su nivel** en su ciudad para jugar/entrenar — el objetivo
final es organizar el partido o la carrera, no una cita. Las dos partes
tienen que poder mirarse el perfil y pensar "che, este tipo juega a mi
nivel" o "ha jugado estos torneos que conozco" — algo que hoy no existe
en absoluto, el perfil no tiene nada de eso. Además, la experiencia de
entrar a la app tiene que ser más cómoda/progresiva — hoy se entra
directo a Discovery con tarjetas de swipe sin ninguna explicación de qué
es esto ni por qué estás viendo caras.

**Diagnóstico (mío) de qué falta para esa experiencia, en orden de
prioridad:**

1. **No había ningún concepto de nivel/habilidad en el modelo de datos.**
   `Profile` no tenía ningún campo de nivel, y no existe ningún registro
   de resultados de partidos, así que tampoco hay de dónde calcular un
   rating real más adelante. Dos pasos, no uno:
   - ✅ **Hecho** (`feat/skill-level-and-credentials`) — corto plazo:
     nivel auto-declarado por deporte (no un único nivel global —
     alguien puede ser avanzado en tenis y principiante corriendo).
     Auto-declarado significa que se puede inflar, es una limitación
     conocida y aceptada por ahora.
   - **Sigue pendiente** — largo plazo: rating calculado (Elo/Glicko, ya
     estaba en el backlog de "Próximos pasos" del README) alimentado por
     resultados de partidos reales — necesita un flujo de "cargar el
     resultado" que hoy no existe ni como concepto. No bloquea el campo
     auto-declarado, que ya está en producción.
2. **✅ Hecho** (`feat/skill-level-and-credentials`) — no había nada que
   generara confianza más allá de una foto y un bio libre. Para el "ha
   jugado estos torneos que conozco": se agregaron campos estructurados
   (años jugando, club, torneos/logros), visibles en el preview del
   perfil, no escondidos en el bio.
3. **Parcialmente hecho.** El onboarding no marcaba el tono, y Discovery
   tampoco — se entraba directo al swipe deck sin explicación. ✅ Se
   agregó el paso de nivel/credenciales al onboarding y un banner
   explicativo (dismissible, una sola vez) al entrar a Discovery por
   primera vez. **Sigue sin hacerse:** no se agregó una pregunta de
   intención explícita nueva (el paso "¿Cuál es tu objetivo?" que ya
   existía — Jugar por nivel/Conocer gente/Ambos — se dejó tal cual, se
   consideró suficiente por ahora en vez de agregar una segunda pregunta
   redundante).
4. **Reconsiderar el mecanismo de swipe y el lenguaje ("Match", corazón)
   — no urgente, no arrancado.** Todo eso se construyó a propósito
   imitando apps de citas. Si el objetivo real es "che, jugás a mi nivel,
   organicemos" en vez de decidir por una foto en 2 segundos, quizás el
   swipe-y-listo es la interacción equivocada del todo. Esto se solapa
   con `redesign/ui-overhaul` (rama creada, sin alcance definido) y
   depende de decisiones de diseño que no tengo — lo dejo fuera del
   trabajo de esta sesión a propósito, documentado acá para cuando se
   hable de esa rama.

**Se me pidió arrancar los puntos 1-3 sin pausas — ✅ hecho.** Rama
`feat/skill-level-and-credentials` (ver "Ramas vivas" y "Hecho" arriba),
pusheada, sin mergear. El punto 4 queda fuera, deliberadamente, por lo
dicho arriba — y dentro de 1-3, el rating calculado (parte larga del
punto 1) también queda fuera, ver el punto en sí.

## Notas del entorno local

- La DB de dev en Docker (`matchpoint_db`) está mapeada al puerto **15432**,
  no el 5432 que asume `.env`/`docker-compose.yml`. Al levantar el backend a
  mano hace falta `DATABASE_URL` apuntando a `127.0.0.1:15432`.
- Cuentas de prueba: `cargo run --bin datagen` siembra 10 perfiles falsos,
  contraseña `password123` (p.ej. `javier.club@example.com`).
