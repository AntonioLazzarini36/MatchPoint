# Estado del proyecto MatchPoint (con Claude Code)

> Documento vivo. Edítalo cuando quieras cambiar prioridades, tachar cosas o
> añadir contexto — lo uso como referencia al arrancar en otros chats.
> Última actualización: 2026-08-04.

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
`fix/discovery-header-cleanup`, `redesign/discovery-cards`, las 10 de la
pasada de seguridad/fiabilidad del 2026-08-01, y `fix/discovery-sports-selection`
+ `feat/skill-level-and-credentials` del 2026-08-02/03) ya está **mergeado en
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
- **`fix/discovery-sports-selection` (2026-08-02, ✅ mergeada en
  `feature/rust-backend` el 2026-08-03 — commit `7eb33e4`, rama borrada
  local y remoto)** — `DiscoveryController` respeta ahora los deportes
  reales del usuario (antes fijo en tenis); fila "Deportes" en Settings
  para poder cambiarlos después del onboarding.
- **Nivel auto-declarado + credenciales, `feat/skill-level-and-credentials`
  (2026-08-02/03, ✅ mergeada en `feature/rust-backend` el 2026-08-03 —
  commit `63ca514`, rama borrada local y remoto)** — primera mitad
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
- **Tres pedidos más + pasada de hardening de inputs (2026-08-03, misma
  rama):**
  - **Volver atrás desde el primer paso del onboarding ahora sale al
    login/registro, con confirmación.** Antes la flecha "atrás" se
    ocultaba del todo en la primera página (no había a dónde volver);
    ahora siempre está, y en la primera página pregunta "¿Salir del
    registro?" antes de mandarte a `/onboarding-auth` — limpia el token
    guardado primero (`TokenStorage.clear()`) para que, si veniste de
    una cuenta a medias ya logueada, el router no te rebote de vuelta a
    `/onboarding` (esa regla de redirect existe para gente con perfil
    incompleto). En el resto de páginas, "atrás" sigue siendo solo
    navegación normal del wizard, sin preguntar nada.
  - **Nuevo paso de preview antes de crear el perfil de verdad.** El
    wizard pasó de 5 a 6 páginas: después de "Sube tus fotos" (que ya
    no crea nada al tocar su botón, solo avanza) hay una página "Así te
    van a ver" con foto, nombre+edad, ciudad, deportes+nivel, bio y
    credenciales — construida con fotos locales (`Image.memory`, no se
    suben todavía) y los mismos bloques visuales que el preview de
    Discovery. El botón "Confirmar y crear perfil" de esa página es el
    que de verdad dispara `_completeRegistration()` (registro + perfil
    + nivel + credenciales + subida de fotos), no el de fotos como
    antes.
  - **Placeholder de logo** en Welcome y en la pantalla de login/
    registro — no hay un logo real todavía, así que es un círculo
    dibujado con ícono (`AppLogoPlaceholder`, fácil de cambiar por
    `Image.asset` el día que haya un logo de verdad). Pedido explícito
    de que esas pantallas se sentían "frías".
  - **Pasada de hardening en todos los inputs nuevos y varios viejos**
    (pedido explícito: "no dejar vulnerabilidades ni opción a poner
    letras... donde se esperan números"):
    - Cliente: `inputFormatters` en años jugando/ritmo/distancia media
      (solo dígitos, o dígitos+`:`+`.` según el campo) en el paso de
      nivel del onboarding y en Settings; `maxLength` en club (100),
      logros (200, tope de 20 logros), nombre mostrado (50), email
      (254) y contraseña (72).
    - Backend: nuevas validaciones de rango/longitud en
      `me/service.rs` (`validate_profile_dto`/`validate_preferences_dto`,
      nuevo `MeError::InvalidInput`, mapeado a 400) — nombre 1-50,
      bio ≤500, ciudad ≤200, lat/lng dentro de rango real, años
      jugando 0-100, club ≤100, hasta 20 logros de ≤200 caracteres
      cada uno, ritmo 1-30 min/km, distancia 0-500km, radio 1-300km,
      edad 18-100, y `ageMin <= ageMax` chequeado *después* de mezclar
      con el valor ya guardado (por si el PATCH solo toca uno de los
      dos). Además, motivo de reporte 1-1000 caracteres
      (`UsersError::InvalidReason`, antes sin ningún límite). Y en
      registro: email con un chequeo básico de formato (antes solo lo
      validaba el cliente, trivial de saltarse llamando a la API
      directo) y contraseña 8-72 caracteres (72 porque bcrypt trunca
      ahí — antes no había mínimo en absoluto, se podía registrar con
      una contraseña de un solo carácter).
  Verificado: fmt/clippy/build/test backend en verde; curl contra el
  backend real confirmando que cada validación nueva rechaza lo que
  tiene que rechazar y sigue aceptando lo válido (contraseña corta,
  email inválido, años jugando fuera de rango, ritmo negativo, string
  donde se espera número, ageMin > ageMax); analyze/test mobile en
  verde.
- **Corrección sobre el hardening anterior (2026-08-03, misma rama):**
  el `maxLength` de Flutter dibuja un contador "X/Y caracteres" debajo
  del campo — feedback del usuario: eso es ruido visual innecesario, y
  de paso los límites elegidos eran más largos de lo necesario. Se
  sacó `maxLength` de club, logros, nombre mostrado, email y
  contraseña (así desaparece el contador) y se acortaron los topes:
  nombre 30 (antes 50), club 60 (antes 100), cada logro 80 (antes 200),
  máximo 10 logros (antes 20) — contraseña se deja en 72 porque es un
  límite técnico real de bcrypt, no una preferencia de UX. La
  validación de longitud se sigue haciendo igual, pero solo al
  intentar avanzar/guardar/añadir un logro, mostrando un mensaje de
  error normal (mismo patrón que "Elige al menos un deporte") en vez
  de un contador permanente. Los campos numéricos (años/ritmo/
  distancia) no llevaban `maxLength` desde el principio — ya usaban
  `inputFormatters` para restringir caracteres, sin contador visible;
  no hizo falta tocarlos. Verificado: analyze/test mobile en verde.

- **Propuestas de partido reales + arreglo de "controles falsos" (2026-08-04)**
  — el análisis del día encontró que dos ajustes que la app ofrecía **no
  hacían literalmente nada**, y que la promesa central del producto
  ("organizar el partido") no existía como tal. Todo arreglado:
  - 🔴 **`Preferences.sportsWanted` se guardaba y nadie lo leía jamás.**
    `DiscoveryController` pedía feeds por `Profile.sports` (lo que juegas),
    no por lo que querías ver. Ahora Discovery se alimenta de
    `sportsWanted`, con `Profile.sports` como valor por defecto si nunca lo
    has tocado.
  - 🔴 **`genderPreference` tampoco filtraba nada** — no existía campo de
    género en `Profile` contra el que comparar. Se añadió enum `Gender`
    (MALE/FEMALE/OTHER, nullable = "prefiero no decirlo"),
    `Profile.gender`, paso de género en el onboarding, y el filtro real en
    `/discover`. Quien no ha declarado género **no** se excluye (mismo
    criterio que el filtro de distancia: vaciar el feed de alguien en
    cuanto pone una preferencia es peor fallo que enseñar perfiles sin
    etiquetar). `datagen` ahora siembra géneros.
  - Para poder *desmarcar* esos dos campos hizo falta distinguir "omitido"
    de "null explícito" en los PATCH parciales — nuevo helper
    `double_option` en `me/dto.rs` y métodos dedicados en el cliente
    (`updateGender`, `genderPreference` como parámetro `required`).
  - **El icono de filtros de Discovery era un `// TODO` inerte.** La hoja
    de preferencias vivía como widget privado dentro de `settings_screen`.
    Extraída a `core/ui/widgets/discovery/discovery_preferences_sheet.dart`,
    se guarda sola, y la usan tanto Ajustes como el botón de Discovery (que
    ahora recarga el feed al guardar, porque cambian los candidatos).
  - **Propuestas de partido con estado (lo grande).** Antes "proponer un
    partido" era un mensaje de chat en texto plano: nada que aceptar, sin
    estado, y se perdía scrolleando. Ahora hay tabla `Proposal` +
    `ProposalStatus`, cuatro endpoints, y reglas de verdad: crear una
    cancela cualquier pendiente del match; solo quien la recibe acepta/
    rechaza y solo quien la hizo cancela; solo se transiciona desde
    PENDING. En el móvil: tarjeta accionable **fijada arriba del chat** (no
    una burbuja más, que es justo el problema que resolvía), flujo único
    `proposeSession` compartido por tenis (con el club preseleccionado
    desde el mapa) y correr, y pantalla nueva **"Próximos partidos"**.
  - **Cuarta pestaña + badges.** La barra de navegación pasó a 4 pestañas
    (Discovery / Matches / Partidos / Profile) con badges reales de
    mensajes sin leer y propuestas esperando tu respuesta, vía
    `GET /me/notifications` (módulo propio, solo contadores, sondeado cada
    15s). **No es push de verdad** — sin FCM la app solo se entera en
    primer plano; lo que arregla es que antes solo te enterabas si entrabas
    tú a mirar esa pestaña.
  - Verificado: fmt/clippy/build/test backend en verde, migraciones
    corridas contra la DB real, y curl end-to-end de todo el ciclo
    (crear → aceptar propio = 403 → aceptar el otro = 200 → re-responder =
    400 → fecha pasada = 400 → deporte que no cuadra = 400 → supersede dejando
    una sola PENDING → filtro de género recortando el feed de 13 a 10 →
    null explícito devolviendo a "cualquiera" → contadores asimétricos).
    analyze/test mobile en verde; desplegado en el Xiaomi.

- **Segunda tanda del 2026-08-04 (feedback en vivo tras probar lo de
  arriba en el móvil):**
  - **Tocar un partido llevaba al chat.** Ahora abre una ficha real
    (`SessionDetailScreen`): cuándo + cuenta atrás ("dentro de 3 días"),
    dónde con **mini-mapa embebido** (no un enlace a Google Maps: se ve si
    cae cerca sin salir de la app), y el rival con las señales que
    responden "¿juega a mi nivel?" (nivel, años, club, logros). El chat
    pasa a ser una acción más, no el destino.
  - **Cancelar un partido ya aceptado.** El backend solo permitía
    transiciones desde PENDING, así que una vez confirmado no había forma
    de echarse atrás salvo no presentarse. Ahora `CANCEL` también funciona
    desde `ACCEPTED`, y puede hacerlo cualquiera de los dos (mientras solo
    está propuesto, sigue siendo solo quien la hizo — la otra parte
    "rechaza", no "cancela").
  - **Punto de encuentro en mapa, no escribiendo el municipio.** Nuevo
    `MapPointPicker`: pin fijo en el centro y el mapa se mueve debajo
    (patrón Uber/Glovo — arrastrar un marcador con el dedo encima lo tapa),
    centrado en la ubicación del perfil, con campo de referencia opcional
    ("junto a la fuente"). Es la opción principal ahora; buscar por nombre
    queda como secundaria. El caso real es "en esta esquina del parque",
    que un buscador de municipios no sabe expresar.
  - **El icono de pistas de tenis salía a todo el mundo**, incluida gente
    que solo corre — desde el chat de un match de correr llevaba a una
    pantalla de clubes inútil. Ahora solo aparece si juegas al tenis.
  - **Fotos en horizontal (16:9) en toda la app.** Nuevo
    `core/utils/landscape_crop.dart` (recorte al centro con `dart:ui`, sin
    añadir dependencia: funciona igual en móvil y web y usa GPU en vez de
    recorrer píxeles en Dart) + diálogo de vista previa "Así se verá"
    antes de aceptar la foto, en los dos sitios donde se suben (onboarding
    y gestor de fotos). La rejilla pasó de 3 columnas cuadradas a 2 en
    16:9, que es lo que el usuario acabó aceptando al subirla.
  - **Paleta nueva de pista de tenis** (verde profundo + lima de pelota)
    en vez del naranja-rojo heredado de cuando la app parecía de citas —
    encaja con el reposicionamiento. Además se extrajeron los
    `ColorScheme` a constantes y se añadieron temas de componentes
    compartidos (navegación, chips, hojas, snackbars, diálogos, divisores)
    que antes no existían: solo estaban estilados botones e inputs, así que
    el resto salía con el aspecto por defecto de Material y desentonaba.
  - Verificado: fmt/clippy/build/test backend en verde; analyze/test mobile
    en verde; `flutter build web --release` limpio y la app arranca en
    Chrome sin excepciones. **Sin repaso visual pantalla por pantalla** —
    las herramientas de navegador estaban bloqueadas en la sesión, así que
    esta tanda queda pendiente de tu revisión visual.

- **Tercera tanda del 2026-08-04 (segunda ronda de feedback en vivo desde
  el móvil):**
  - **Texto blanco invisible en todos los chips.** Los logros del rival,
    "Tenis"/"Correr", "Cualquiera"/"Hombres", los niveles… salían en
    blanco sobre fondo claro. Causa real: `ChipThemeData.labelStyle`
    **no** pasa por el `.apply(bodyColor:…)` que `ThemeData` le hace al
    `textTheme`, así que al declararlo sin color el texto se quedaba sin
    color en toda la cadena y el motor de Flutter pintaba su default, que
    es blanco. Arreglado en el tema (`WidgetStateColor` según
    seleccionado/deshabilitado + `iconTheme`), no chip a chip: el bug
    estaba en un sitio, no en ocho pantallas. De paso, el fondo del chip
    pasó a `surfaceContainerHighest` — con `surface` era del mismo color
    que la pantalla y no se distinguía del texto suelto.
  - **Los logros del rival ya no van en `Chip`.** En la ficha de la
    quedada son frases largas ("Subcampeón del torneo de…") y dentro de
    una píldora se cortaban; ahora son filas con icono, como en el resto
    de perfiles. Además se muestran **todos**, no sólo el primero.
  - **Las propuestas pendientes ya aparecen en la pestaña de quedadas.**
    Antes `GET /me/proposals` sólo devolvía ACCEPTED, así que una
    propuesta recién recibida sólo existía dentro del chat que la traía
    — invisible justo en la pantalla que contesta "¿qué tengo por
    jugar?". Ahora devuelve también PENDING y la pantalla las agrupa en
    tres secciones ("Esperan tu respuesta" primero, luego "Confirmadas",
    luego "Esperando respuesta"). La ficha de la quedada acepta, rechaza y
    retira desde ahí, con las mismas reglas que la tarjeta del chat.
  - **"Partidos" → "Quedadas".** A quien sólo corre, una pestaña llamada
    "Partidos" le hablaba de algo que no hace. "Quedada" vale para los dos
    deportes y, a diferencia de "propuesta", sigue siendo correcto una vez
    aceptada. Nuevo `core/utils/sport_words.dart` con el vocabulario
    (`sportSessionTitle`/`sportSessionNoun`/`sportIcon`) para que no se
    vuelva a desincronizar: los botones dicen "Cancelar partido" o
    "Cancelar salida" según el deporte de esa quedada.
  - **Elegir club de tenis al proponer.** El buscador de sitios es un
    geocodificador (Nominatim) y en la práctica sólo devuelve municipios
    y calles: buscar "club de tenis" no encontraba nada. Nuevo
    `TennisClubPicker`, que reutiliza el `OverpassService` del mapa de
    clubes (datos reales de OSM por etiqueta), ordena por distancia, deja
    filtrar por nombre y ampliar de 10 a 30 km. En tenis es ahora la
    opción principal; corriendo sigue mandando el mapa con el pin.
  - **Subir varias fotos a la vez.** `pickMultiImage` + un "Así se
    verán" que muestra las N ya recortadas a 16:9, con opción de quitar
    las que no convenzan antes de subirlas. Ir de una en una (elegir,
    recortar, confirmar, subir, repetir) es justo lo primero que hace
    alguien recién llegado.
  - **Los perfiles enseñan todas las fotos, en horizontal y scrolleando.**
    El carrusel lateral escondía todo menos la primera foto detrás de un
    gesto que nada indicaba. Ahora la cabecera es un 16:9 exacto del ancho
    de pantalla (la misma proporción en la que se guardan) y el resto van
    apiladas en una sección "Fotos". Igual en el preview de Discovery y en
    el paso de "Así te van a ver" del onboarding, que seguían en cuadrado.
  - **Desbordes de layout arreglados:** el formulario de login/registro no
    tenía scroll y al abrir el teclado desbordaba 54 px; la pantalla de
    bienvenida desbordaba 82 px en pantallas cortas (dos `Spacer`, que no
    pueden encogerse por debajo de cero). Los dos con
    `SingleChildScrollView` — en Welcome con `ConstrainedBox` +
    `IntrinsicHeight` para que los `Spacer` sigan centrando cuando sí
    cabe.
  - **Más tema:** `AppBarTheme` propio (sin tinte de superficie, título
    en Poppins), `TextButtonThemeData`, `SliderThemeData` (el `RangeSlider`
    de edad salía con el morado por defecto de Material),
    `TooltipThemeData`, `ProgressIndicatorThemeData` e `IconThemeData`.
    Etiquetas de la barra de navegación siempre visibles. Se sustituyeron
    los `Colors.red`/`Colors.green` sueltos por `error`/`primary` del
    esquema. Login/registro y Welcome pasados a castellano (eran las
    únicas pantallas que seguían en inglés).
  - **Los clubes se llamaban todos igual** (feedback inmediato al probarlo):
    la etiqueta `name` de OpenStreetMap casi nunca está en las pistas de
    tenis — **3 de 106 cerca de Benalmádena**, comprobado con la consulta
    real — así que el relleno "Club de tenis" se comía la lista entera y
    quien recibía la propuesta no sabía a dónde ir. Tres cosas:
    1. La consulta de Overpass pide también `sports_centre`/`club=tennis`
       (pocas, pero son las que sí llevan nombre) y las etiquetas `addr:*`,
       y al agrupar el nombre de la instalación gana al de una pista suelta.
    2. Los sin nombre se resuelven por geocodificación inversa
       (`GeocodingService.reverse`, nuevo) a una dirección real — sólo los
       **12 más cercanos**, uno cada 1,1 s, porque la política de Nominatim
       pide ~1 petición/segundo y nadie queda en la pista número 40 por
       distancia. Los demás se resuelven al elegirlos, con una sola
       petición.
    3. Al elegir uno sin nombre se pide confirmación con el nombre
       **editable** (`askPlaceName`, compartido con el mapa de clubes),
       propuesto como "Pistas de tenis · Avenida de Alay, Benalmádena". Así
       quien conoce el sitio puede escribir cómo lo llama todo el mundo.
    El relleno pasó de "Club de tenis" a "Pistas de tenis": lo primero
    afirma algo que no sabemos (que sea un club).
  - **El error de Overpass ya no es un ladrillo rojo.** Salía el texto
    crudo de la excepción (`TimeoutException after 0:00:20...`) sobre
    `errorContainer`, ocupando media pantalla. Overpass es el servicio
    público y gratuito de OSM, lo comparte todo el mundo y se satura a
    ratos: no es un fallo de la app. Ahora es un aviso neutro de una línea
    ("El servicio de mapas está saturado. Reintenta en unos segundos.")
    con su botón, y el detalle técnico va a `debugPrint`. Mismo trato en
    el selector de clubes.
  - Verificado: fmt/clippy/test backend en verde; `flutter analyze`/`test`
    en verde; y curl end-to-end de la agenda (propuesta PENDING creada por
    una cuenta → aparece en `/me/proposals` de la otra con `mine=false` y
    `pendingProposals: 1`).

- **Cuarta tanda del 2026-08-04 (rediseno de Discovery y calidad de datos):**
  - **Discovery ya no enseña perfiles a medias.** `/discover` exige ahora
    al menos una foto **y** coordenadas. Es un cambio deliberado de
    criterio respecto al "no castigues al que no ha rellenado algo" del
    filtro de distancia: entonces la ubicación era opcional en el
    onboarding y exigirla habría vaciado el feed; ahora el onboarding no
    deja pasar del paso de ubicación ni terminar sin foto, así que un
    perfil sin ellas es una cuenta a medio crear, no alguien a quien se
    esté castigando. Se mantienen los dos carve-outs que sí siguen
    teniendo sentido: un *viewer* sin coordenadas no se filtra por
    distancia, y quien no ha declarado género nunca se excluye.
  - **Los 10 perfiles de prueba tenían cero fotos**, así que el filtro de
    arriba los habría borrado del mapa. `datagen` genera ahora dos fotos
    por perfil (pista de tierra batida / tartán en perspectiva, 1280×720,
    con el crate `png`) y **rellena las de un perfil ya sembrado que no
    tenga**, para que re-ejecutarlo repare una base de datos vieja. Se
    dibujan en vez de descargarse: funciona sin red, es determinista y no
    finge ser una persona real. Borradas además 4 cuentas basura de
    registros abortados (`onboarding-flow-test`, `photos-verify`,
    `antonio`, `prueba1`) — sin fotos, sin ubicación, sin swipes ni
    matches.
  - **Tres señales nuevas en cada candidato**, calculadas donde ya estaban
    los datos: `distanceKm` (la cifra derivada; las coordenadas del otro
    siguen sin salir del servidor), `matchesYourLevel` y `likesYou`. Son
    **relativas a quien mira**, así que `/users/:userId/profile` y el lado
    `otherUser` de `/matches` las fuerzan a false/None a propósito. El feed
    se ordena por ellas: primero quien ya te dio like (tu like cierra el
    match al instante), luego quien juega a tu nivel, luego el resto.
  - **Tarjetas de Discovery rehechas.** Antes eran miniaturas con el
    nombre en `labelMedium` y un badge de nivel: no se leían y no daban
    ningún motivo para arrastrarlas. Ahora: nombre+edad en `titleLarge`,
    píldoras de deporte+nivel y distancia, marca de agua difuminada de la
    raqueta/corredor, y borde + chapa de acento cuando la persona te ha
    dado like ("Te ha dado like", lima) o juega a tu nivel ("A tu nivel",
    verde). De 4 tarjetas a **3**, y **escalonadas** (cada una desplazada
    18 px al lado contrario de la anterior) — con 4 no cabía información
    en ninguna y alineadas al milímetro parecía una tabla. Cabecera con
    subtítulo real ("7 perfiles de tenis cerca de ti") y, abajo, la
    leyenda del gesto, que de paso llena el hueco del zigzag.
  - **Preview rehecho.** Foto grande con el nombre encima en vez de foto
    cuadrada y bloque de texto suelto; recuadro que *explica* por qué el
    perfil está destacado (el borde de color llamaba la atención pero no
    decía nada); deporte+nivel como tarjetas y no chips; ciudad y
    distancia bajo el nombre; el resto de fotos en vertical.
  - **Overpass se satura menos.** Se añadió `overpass.kumi.systems` como
    primer espejo (el de más capacidad de los públicos) y una caché en
    memoria por (lat, lng, radio) redondeados a ~11 m: el mapa de clubes y
    el selector de sitio preguntan casi siempre por el mismo punto — tu
    ubicación de perfil — así que antes cada entrada era otra consulta a
    un servicio público saturado. Las pistas de una zona no cambian en lo
    que dura una sesión.
  - Verificado: fmt/clippy/build/test backend en verde; `flutter analyze`/
    `test` en verde y `flutter build web --release` limpio; y curl contra
    el backend real confirmando el orden del feed (para Lucía, primero
    quien le dio like, luego los tres INTERMEDIATE de tenis, luego el
    resto), las distancias reales y que los 13 candidatos tienen foto.
    **Sin probar en el móvil**: no estaba conectado en esta tanda.

- **Los clubes de tenis seguían sin nombre (2026-08-04, quinta tanda)** —
  y no eran los datos, era la consulta. Se propuso montar una base de datos
  propia con los clubes de España/Europa; **no hacía falta**: "Club de
  Tenis Capellanía" ya está mapeado en OSM, lo que pasaba es que su
  `leisure=sports_centre` **no lleva etiqueta `sport`** y la consulta pedía
  `sports_centre` *exigiendo* `sport~tennis`. Medido con curl cerca de
  Benalmádena: 110 instalaciones en 15 km, 79 con nombre, y la consulta
  vieja se quedaba con 3.
  - Ahora se piden **todas** las instalaciones de la zona (`sports_centre`
    y cualquier `club=*`, sin filtrar por deporte) y el nombre se le pega
    al grupo de pistas que tenga a menos de 300 m. Resultado en la misma
    zona: de 0 clubes con nombre a **17**, incluidos los grandes (Lew Hoad
    8 pistas, Complejo Tenis Málaga 7, Algarrobo 5, Capellanía 4, Sohail
    4).
  - Una instalación sólo presta su nombre si no tiene etiqueta `sport`, o
    si menciona tenis, o si es `multi`. Sin ese filtro, unas pistas al lado
    de "Karting Mijas" saldrían llamándose así — y un nombre equivocado es
    peor que ninguno.
  - Los grupos de pistas que resuelven a la misma instalación se fusionan
    (un complejo grande se partía en dos y salía duplicado), y la lista se
    ordena **con nombre primero** y luego por cercanía: ordenar sólo por
    distancia dejaba arriba pistas sueltas de urbanización y enterraba el
    club de 8 pistas de al lado.
  - Descartado a propósito buscar por nombre en Overpass
    (`name~"[Tt]enis"`): una regex sobre nombres en 15 km devuelve 504,
    comprobado. Una base de datos propia sigue siendo una opción si algún
    día se quiere búsqueda instantánea u offline, pero significa pipeline
    de importación, almacenamiento y datos que caducan — no compensa para
    lo que arregla una consulta bien hecha.

- **Preparación para desplegar, primera tanda (2026-08-05)** — arreglos de
  código previos a sacar la app de "el backend corre en mi portátil". Lo
  importante de entender: **mover sólo la base de datos a la nube no
  soluciona nada**; lo que hay que desplegar es la API y la base juntas
  tras una URL pública. Estos son los bloqueos que venían de antes:
  - **Las fotos se validaban por el `Content-Type` que manda el cliente**,
    sin mirar el archivo jamás: cualquiera podía subir un HTML, un zip o
    un ejecutable etiquetado como `image/png` y quedábamos sirviéndolo
    desde nuestro dominio. Ahora la cabecera **se ignora por completo** y
    la extensión sale de los primeros bytes (`sniff_extension` en
    `me/photos.rs`, tres firmas, sin crate nueva). Con tests: rechaza
    HTML/exe/zip/RIFF-que-no-es-WebP y entradas truncadas, y acepta un PNG
    real aunque venga como `application/octet-stream`. Comprobado también
    con curl contra el backend real.
  - **`AppConfig::validate`** (nuevo `APP_ENV`): avisa en dev y **no deja
    arrancar en producción** si los secretos siguen siendo los de ejemplo
    del repo (que son públicos), si son cortos, si `CORS_ALLOWED_ORIGINS`
    está vacío o si `PUBLIC_BASE_URL` sigue en localhost. Un fallo ruidoso
    al desplegar es mejor que un servicio en pie con secretos públicos.
  - **CORS configurable** por `CORS_ALLOWED_ORIGINS` en vez de `Any` fijo.
  - **`/health` consulta la base** (timeout 2s) y devuelve **503** si no
    responde. Antes devolvía `{ok:true}` fijo, así que un balanceador o un
    healthcheck de Docker daría "sano" con Postgres caído.
  - **Rate limiter tras proxy**: con `TRUST_PROXY=true` lee
    `X-Forwarded-For`. Sin esto, detrás de Fly/Railway/nginx vería la IP
    del proxy para todo el mundo y el límite de login dejaría de ser por
    cliente — un solo atacante bloquearía a todos. Es opt-in porque esa
    cabecera la pone quien llama: confiar en ella **sin** proxy delante
    permitiría saltarse el límite inventando una IP por intento.
  - `.env.example` documenta ahora todas las variables, con los avisos de
    qué pasa al cambiar `MESSAGE_KEY_BASE64` (los mensajes ya cifrados
    quedan ilegibles) y de que `PHOTOS_DIR` se borra en cada despliegue si
    no hay volumen persistente.
  - Verificado: fmt/clippy/build en verde, 5 tests (4 nuevos), y curl
    contra el backend real — `/health` 200, arranque en producción
    abortando con los 6 problemas listados, HTML-como-PNG rechazado con
    400, PNG real aceptado.

  **Lo que sigue bloqueado y por qué:**
  - **Fotos en almacenamiento de objetos (S3/R2).** Es el único bloqueo
    de despliegue que queda: en un contenedor sin volumen, `PHOTOS_DIR` se
    borra en cada despliegue y todo el mundo pierde sus fotos. No se
    implementó a ciegas porque hace falta una cuenta y un bucket contra el
    que probarlo, y código de subida sin probar no vale. **Ojo:** varios
    proveedores (Fly, Railway) ofrecen volumen persistente, que resuelve
    esto con cero código — sólo apuntar `PHOTOS_DIR` al volumen.
  - **Login con Google/Apple**: necesita Client ID de Google Cloud Console
    y cuenta de Apple Developer (99 $/año). Ver la sección de 2026-08-01
    más abajo, sigue igual.
  - **Verificación de email / 2FA**: necesita un proveedor de envío
    (Resend, SendGrid, SES) con sus credenciales. El modelo de datos y los
    endpoints se pueden hacer con un transporte de dev que imprima el
    enlace por consola, pero conviene decidir el proveedor antes para no
    tirar trabajo.

- **Verificación de email, backend completo (2026-08-05)** — hasta ahora
  cualquiera podía registrarse con el correo de otra persona porque nadie
  comprobaba que le perteneciera.
  - Migración: `User.emailVerifiedAt` (fecha y no booleano: "cuándo lo
    verificó" es dato útil y el booleano se deduce) y tabla
    `EmailVerification`.
  - **Código de 6 dígitos, no enlace**: en una app móvil escribir seis
    números es más directo que abrir un enlace, no necesita deep links, y
    es la misma pieza que hará falta luego para 2FA.
  - Defensas: 15 min de vida, 5 intentos por código, 60 s de cooldown entre
    reenvíos, y sólo un código válido a la vez. Se guarda el SHA-256 del
    código (no bcrypt: lo que protege 6 dígitos es el TTL y el límite de
    intentos, no el coste de hashear). El código se genera de un UUID v4,
    que ya viene del CSPRNG del sistema — sin añadir la crate `rand`.
  - Los dos endpoints piden **autenticación**: así sólo puedes pedir el
    código de tu propia cuenta, y nadie puede usar el endpoint para
    bombardear el buzón de otra persona metiendo su email.
  - `mail::Mailer` con dos transportes: **Resend** si hay `RESEND_API_KEY`,
    y si no un transporte de **log** que escribe el correo (con el código
    visible) por consola. Así el flujo entero se desarrolla y se prueba sin
    credenciales, y nadie tiene que comentar código para compilar.
    `AppConfig::validate` avisa (y en producción aborta) si falta la key,
    para que nadie despliegue creyendo que envía correos.
  - Nueva dependencia: `reqwest` con **rustls** y no TLS del sistema, para
    no depender de OpenSSL (que es justo lo que da guerra en Windows y en
    la imagen slim de Docker).
  - Verificado con curl contra el backend real, capturando el código del
    log: `emailVerified` false → pedir código 204 → reenviar antes de
    tiempo 429 → código incorrecto 400 → código correcto 200 →
    `emailVerified` true → volver a pedirlo 400.

  **UI del móvil, hecha (misma fecha):** `EmailVerificationScreen` con
  campo de 6 dígitos (sólo números, verifica solo al completar el sexto —
  pedir además un toque en el botón no aporta nada), pide el código al
  entrar, y botón de reenvío con cuenta atrás de 60 s en el cliente para no
  dejar pulsar algo que ya sabemos que va a dar 429. Se entra desde la fila
  "Email" de Ajustes, que ahora enseña el estado siempre (verificado /
  sin verificar, y sólo es pulsable en el segundo caso). Al volver se
  recarga `/me` en vez de fiarse del resultado de la pantalla.

  **Sigue sin bloquear nada** a propósito: exigir email verificado para
  usar la app dejaría fuera de golpe a todas las cuentas que ya existen.
  Cuándo y para qué se exige es una decisión de producto pendiente.

  **Aviso de Resend:** sin un dominio verificado sólo se puede enviar desde
  `onboarding@resend.dev` y **únicamente al email con el que se creó la
  cuenta de Resend**. Para probarlo con otra persona hace falta verificar un
  dominio propio (registros DNS).

- **Listo para desplegar en Railway (2026-08-05)** — elegido Railway por ser
  el más simple de los tres candidatos. Todo lo automatizable está hecho;
  queda pulsar cosas en su panel, que es lo que explica `DEPLOY.md`.
  - **Migraciones dentro del binario** (`src/migrate.rs`, `embed_migrations!`)
    y aplicadas al arrancar, antes de construir el pool. Un despliegue no
    tiene consola donde correr `diesel migration run`, y un servicio
    sirviendo contra un esquema viejo falla de formas raras (columna que no
    existe) en vez de fallar claro. `RUN_MIGRATIONS=false` lo desactiva.
    Aviso: la copia embebida se lee **al compilar**, así que en local una
    migración nueva necesita recompilar para que la coja.
  - `Dockerfile`: copia `migrations/` en la fase de build (el macro las
    necesita al compilar), crea `/app/uploads` para que arranque sin
    volumen, y documenta que `PORT` lo inyecta la plataforma.
  - `railway.json` (builder DOCKERFILE, healthcheck en `/health`, reinicio
    ante fallo) y `.dockerignore` para no meter `target/` en el contexto.
  - **`DEPLOY.md`**: guía paso a paso — generar secretos, Root Directory
    `services/api-rust`, Postgres, la tabla de variables, dominio y
    `PUBLIC_BASE_URL`, CORS, y **el volumen en `/app/uploads`**, que es lo
    que más fácil se olvida: sin él cada despliegue borra las fotos de
    todo el mundo, y como `/discover` exige foto, los perfiles desaparecen
    del feed.
  - **Verificado de verdad, no sólo compilado**: imagen construida con
    `docker build`, arrancada con `APP_ENV=production` y secretos reales
    contra una base **vacía**. Aplicó las 9 migraciones sola, creó las 12
    tablas, `/health` devolvió 200 y un `POST /auth/register` contra esa
    base recién migrada funcionó. También confirmado que con la config de
    dev y `APP_ENV=production` se niega a arrancar listando los problemas.

  **Lo que falta y le toca al usuario:** crear la cuenta de Railway, el
  proyecto y el volumen (no puedo crear cuentas). Y decidir dónde se
  publica la web, para poder fijar `CORS_ALLOWED_ORIGINS`.

- **Primera tanda con la app ya desplegada (2026-08-05)** — feedback tras
  usarla contra Railway desde el móvil, sin cable.
  - **El APK de release no tenía permiso de internet.** Flutter declara
    `INTERNET` sólo en los manifests de `debug` y `profile`, que no se
    mezclan en release: toda petición fallaba con "Failed host lookup",
    como si el móvil no tuviera red. No se nota hasta el primer build de
    release, que es justo el que se le manda a alguien para probar.
  - **Atar a `[::]` no da IPv4 en Windows.** El arreglo para Railway (su
    red privada es sólo IPv6) rompió el desarrollo local: en Windows
    `IPV6_V6ONLY` viene **activado**, así que `127.0.0.1:3000` dejó de
    responder aunque el log dijera "listening". Ahora el socket se abre a
    mano con `socket2` apagando ese flag — IPv6 e IPv4 en el mismo
    listener, en los dos sistemas. Comprobado contra `127.0.0.1` y `[::1]`.
  - **Verificación de email en el flujo**, no escondida en Ajustes: se
    ofrece al terminar el registro, que es cuando alguien tiene el correo a
    mano. Con botón "Más tarde" — no verificar no bloquea nada todavía, y
    un muro nada más registrarse es la forma más rápida de que no llegue a
    probar la app.
  - **Cámara**: hoja de "hacer una foto / elegir de la galería" en los dos
    sitios donde se suben fotos. Antes obligaba a salir de la app, hacerse
    la foto y volver. Añadidas de paso las descripciones de uso de iOS, que
    faltaban y habrían cerrado la app al pedir permiso.
  - **Confirmación antes de guardar en Ajustes** (`confirmChanges`): cada
    hoja guardaba en cuanto se cerraba, así que un toque sin querer te
    cambiaba el perfil sin avisar ni decir qué. Ahora se listan los campos
    que cambian, con el valor viejo tachado y el nuevo. Sólo los que
    cambian de verdad; repetir los iguales convierte el diálogo en ruido.
  - **Los dos deportes dejan de pelearse:**
    - `Match.sport` ya no decide qué se puede proponer. Sólo dice por qué
      feed os cruzasteis; lo que importa es qué practicáis **los dos**
      (`assert_both_play`). Antes, con ambos jugando a los dos deportes,
      sólo se podía proponer el del match. Verificado: proponer correr en
      un match de tenis entre dos que corren → 200; proponérselo a quien
      sólo juega al tenis → 400.
    - En el chat sale **un botón por deporte compartido** en vez de uno
      fijo por el deporte del match.
    - **El deporte se ve en la lista de matches**: con las dos
      conversaciones mezcladas, el nombre solo no decía si era de tenis o
      de correr, y eso cambia lo que vas a proponer.
    - **Fuera el icono de raqueta de la AppBar de Matches** (pedido). El
      mapa de clubes se movió al menú del chat y sólo en chats de tenis,
      para no dejar la pantalla sin ninguna entrada.
  - Verificado: fmt/clippy/test backend en verde (9 tests), analyze/test
    mobile en verde, y curl contra el backend real para el cambio de
    deportes y para el socket dual-stack.

  **Aviso — datos de dev borrados sin querer:** al limpiar los matches de
  prueba creados para verificar lo del deporte, el filtro
  (`%@example.com` en ambos lados) se llevó también matches y propuestas
  anteriores entre perfiles sembrados. Sobrevivieron las cuentas
  `photos*@test.com`, la de Mario y sus 6 likes recibidos.

  **Notificaciones — sigue sin haber push de verdad.** Los badges de la
  barra se refrescan sondeando `/me/notifications` cada 15 s, pero sólo
  con la app abierta: con la app cerrada no llega nada, y eso no se
  arregla con más código. Hace falta un proyecto de Firebase
  (`google-services.json`) para FCM.

- **Borrar cuenta e interruptor de verificación (2026-08-05, tarde):**
  - **`DELETE /me`** — borraba el hueco de RGPD que llevaba anotado desde
    el 2026-08-02. Las tablas cuelgan de `User` con `ON DELETE CASCADE`,
    así que una sentencia se lleva perfil, swipes, matches, mensajes y
    propuestas; los **ficheros** de las fotos no los borra ningún cascade,
    viven en disco, y hay que quitarlos a mano o quedan huérfanos para
    siempre. Se borran **después** de que la fila desaparezca: si el
    borrado fallara, quedaría una cuenta viva sin sus fotos.
  - **Confirmación escribiendo "BORRAR"**, no un sí/no. Un diálogo de dos
    botones se despacha con un toque reflejo y esto no tiene deshacer. El
    diálogo lista **qué se pierde en concreto** (conversaciones, partidos
    acordados, fotos) en vez de "tus datos", y el botón está deshabilitado
    hasta escribir la palabra. Verificado con curl: registro → `/me` 200
    → `DELETE /me` 204 → `/me` 404 → 0 filas en la base.
  - **`EMAIL_VERIFICATION_ENABLED`** — interruptor en el servidor, no en
    la app. Sin dominio de correo propio, Resend sólo entrega al titular
    de la cuenta, así que con la verificación encendida cualquier amigo
    que se registre choca contra un fallo de envío nada más crear la
    cuenta. Apagado: los endpoints responden 503 y `/me` expone el flag
    para que la app esconda la pantalla y la fila de Ajustes. Va por el
    servidor a propósito: el día que haya dominio se enciende cambiando
    una variable, sin publicar una versión nueva ni pedirle a nadie que
    actualice.
  - **Credenciales separadas por deporte** en el onboarding y en Ajustes:
    con los dos deportes elegidos, "años jugando" y "club" caían justo
    encima de "ritmo medio" sin nada que dijera cuál era de qué. Cabecera
    con el icono del deporte, y sólo cuando hay dos — con uno solo sería
    ruido.
  - **Hueco de reserva para fotos que no cargan** (`NetworkPhoto`):
    `Image.network` a pelo deja un recuadro gris cuando la URL da 404, y
    eso pasa de verdad mientras no haya volumen persistente.

## Pendiente / próximos pasos

### Sin empezar, esperando tu decisión
- **`redesign/ui-overhaul`** — falta definir alcance/estilo.
- **`test/full-app-suite`** — para que la escribas vos.
- ~~**UI de preferencias de Discovery**~~ — hecha el 2026-08-04 (ver arriba).
- **Rating calculado** (Elo vs Glicko-2), a partir de resultados de
  partidos reales — el nivel *auto-declarado* por deporte ya existe
  (`feat/skill-level-and-credentials`, ver "Hecho"), esto es la parte
  larga/pendiente: no hay ningún flujo para cargar el resultado de un
  partido jugado, ni tabla para guardarlo, ni cómo lo usaría `discover`
  para emparejar.
- ~~**Distancia real**~~ — resuelto en `feat/manual-location` (ver
  "Hecho"), pendiente de que la revises y mergees.
- ~~**Campo de género**~~ — hecho el 2026-08-04 (ver arriba).
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

1. **El feed no se re-pide solo cuando quedan pocas tarjetas.** `reload()` solo se llama a mano ("Reiniciar
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
5. **Push de verdad (FCM/APNs) sigue sin existir.** Parcialmente
   mitigado el 2026-08-04: badges en la barra de navegación con contadores
   reales (`GET /me/notifications`, sondeado cada 15s), así que ya no hace
   falta entrar a mirar para enterarte. Pero con la app cerrada o en
   segundo plano no llega nada. Push real necesita un proyecto de Firebase
   (`google-services.json`) y credenciales que hay que crear — mismo
   bloqueo "necesito que consigas algo externo" que OAuth y el envío de
   emails.

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

**Se me pidió arrancar los puntos 1-3 sin pausas — ✅ hecho, y ya
mergeado en `feature/rust-backend`** (ver "Hecho" arriba —
`feat/skill-level-and-credentials`, rama borrada tras el merge). El
punto 4 queda fuera, deliberadamente, por lo
dicho arriba — y dentro de 1-3, el rating calculado (parte larga del
punto 1) también queda fuera, ver el punto en sí.

## Notas del entorno local

- La DB de dev en Docker (`matchpoint_db`) está mapeada al puerto **15432**,
  no el 5432 que asume `.env`/`docker-compose.yml`. Al levantar el backend a
  mano hace falta `DATABASE_URL` apuntando a `127.0.0.1:15432`.
- Cuentas de prueba: `cargo run --bin datagen` siembra 10 perfiles falsos,
  contraseña `password123` (p.ej. `javier.club@example.com`).
