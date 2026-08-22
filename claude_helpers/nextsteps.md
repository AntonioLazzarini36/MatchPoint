# Próximos pasos: de "funciona" a "publicable en Google Play"

> Escrito el 2026-08-06, tras el repaso completo de la app ya desplegada en
> Railway y funcionando en móvil y web. Ordenado por lo que **bloquea** la
> publicación, no por dificultad.
>
> Al final está la lista de **lo que necesita algo tuyo** (dominio, cuentas,
> decisiones irreversibles) separada de lo que se puede hacer sin esperar a
> nadie. Empezar por ahí ahorra bloqueos a media tarea.

---

## 🔴 Bloqueos duros — Google Play la rechaza automáticamente

### 1. ~~El applicationId es `com.example.match_point`~~ ✅ hecho (2026-08-21)
Ahora es **`com.matchpoint.app`** (Android y iOS). Detalle en `status.md`.

⚠️ Sigue siendo **la decisión más irreversible de toda la lista**, sólo que
ya está tomada: a partir de la primera publicación no se puede cambiar. Si
por lo que sea hay que cambiarlo (p. ej. porque el dominio que se compre
sugiera otro), **el momento es antes de subirla a Play**, no después.

### 2. ~~Firmada con la clave de debug~~ ✅ hecho (2026-08-21)
Keystore PKCS12 en `~/keys/matchpoint-release.p12`, credenciales en
`apps/mobile/android/key.properties` (ignorado por git). El APK de release ya
sale firmado con él, comprobado con `apksigner`.

🔴 **Lo que falta y le toca al usuario: la copia de seguridad del keystore.**
Ahora mismo existe en **un solo disco**. Si se pierde ese archivo o su
contraseña, la app publicada no se puede volver a actualizar jamás — hay que
publicar otra app desde cero. Guardar copia del `.p12` **y** de la contraseña
en sitios distintos del portátil.

### 3. ~~Nombre e icono de fábrica~~ ✅ hecho (2026-08-21)
Se llama **MatchPoint** en Android, iOS y web, y tiene icono propio: el logo
circular partido (raqueta / zapatilla) que aportaste, recoloreado a los
colores de deporte de la app y con el blanco cambiado por pizarra.
`apps/mobile/tool/gen_app_icon.dart` lo deriva del original en
`tool/logo_source.png`.

Pendiente sólo si se quiere: un logotipo con **la palabra "MatchPoint"** y
tipografía propia, para la ficha de Play y la cabecera de la web. El icono
actual es sólo el símbolo.

### 4. Política de privacidad
Obligatoria, con URL pública y accesible. Se recogen email, fotos y
ubicación, así que no hay excepción posible.

### 5. Formulario de Data Safety
Hay que declarar en la ficha de Play qué datos se recogen, para qué, si se
comparten y si se pueden borrar. El borrado ya existe (`DELETE /me`), que es
uno de los puntos que Play comprueba.

### 6. Política de contenido generado por usuarios
Play exige tres cosas para apps con contenido de usuarios:
- **Reportar** → ✅ existe (`POST /users/:id/report`)
- **Moderar** → ✅ cola de moderación (ver punto 7)
- **Bloquear** → ⚠️ se quitó Block a propósito (unmatch + report se
  consideraron suficientes). El unmatch corta el contacto, así que
  probablemente cumple, pero conviene tenerlo claro antes de que lo
  pregunten en la revisión.

---

## 🟠 Lo que rompería la experiencia con usuarios reales

### 7. ~~Los reportes no los revisa nadie~~ ✅ hecho (2026-08-22)
`GET /admin/reports` da la cola (sin revisar, lo más viejo primero) con ambas
partes y cuántas veces ha sido denunciada esa persona en total.
`PATCH /admin/reports/:id` la cierra dejando escrito qué se decidió.
Protegido por `ADMIN_API_KEY` en la cabecera `X-Admin-Key`, ya puesta en
Railway y verificada contra producción. Responde 404 y no 401 si la clave
falla, para no confirmar que la ruta existe.

### 8. ~~Notificaciones push~~ ✅ HECHO Y PROBADO EN PRODUCCIÓN (2026-08-22)

Hecho y desplegado (2026-08-22): proyecto de Firebase, tabla `DeviceToken`,
`POST/DELETE /me/devices`, envío por FCM HTTP v1 desde el backend, y avisos
al recibir mensaje, propuesta, respuesta a una propuesta y match nuevo. En el
móvil: SDK, permiso de Android 13+ (comprobado concedido en el Xiaomi) y
registro del token al arrancar y al iniciar sesión.

Verificado de punta a punta con el móvil real y **la app cerrada**: like →
match, mensaje, y propuesta de quedada. Las tres notificaciones llegaron.
`FIREBASE_SERVICE_ACCOUNT_JSON` y `ADMIN_API_KEY` están puestas en Railway.

⚠️ **Pendiente tuyo:** rotar la clave de Firebase — se envió por chat a
petición tuya para poder configurarla desde el móvil. Firebase console →
Configuración del proyecto → Cuentas de servicio → borrar esa clave y generar
otra.

Queda además un detalle de acabado: el icono de la barra de estado saldrá
como silueta blanca hasta que se genere uno monocromo (mismo
`tool/gen_app_icon.dart`) y se declare en el manifest.

### 9. Verificación de email desactivada
`EMAIL_VERIFICATION_ENABLED=false` mientras no haya dominio de correo. Con
esto apagado, cualquiera se registra con el email de otra persona. Ver la
sección de dominio abajo: se enciende sin publicar versión nueva.

### 10. ~~Rate limiting sólo en los endpoints de auth~~ ✅ hecho (2026-08-22)
Swipes 60/min, mensajes 30/min, fotos 20/hora, reportes 10/hora — **por
usuario**, no por IP (media ciudad comparte IP tras un CGNAT, y cambiar de IP
no le cuesta nada a quien abusa). Verificado en producción: corta en la
petición 61.

⚠️ Sigue en pie el aviso: el limitador cuenta **en memoria del proceso**, así
que con varias instancias el límite efectivo se multiplica por N. Con una,
correcto.

### 11. Cobertura de tests — mejorada (2026-08-22), no terminada
Backend: 18 unitarios + **10 de integración contra base real**, uno por cada
regla que ya se rompió (match entre deportes, filtro de Discover, reglas de
propuestas). Comprobado que sirven reintroduciendo el bug original: falla
justo el test que lo cubre. Móvil: de 1 (plantilla) a 7.

Lo que sigue sin cubrirse: auth y el ciclo de fotos en el backend, y
prácticamente toda la UI del móvil.

---

## 🟡 Pulido que se nota al usarla

### 12. ~~Botones muertos en la pantalla de bienvenida~~ ✅ hecho (2026-08-21)
Quitados. Vuelven cuando el login social funcione de verdad.

### 13. ~~Pantalla fantasma~~ ✅ hecho (2026-08-21)
`/partner` borrada entera: ruta, import y archivo.

### 14. ~~Sin manejo de "no hay conexión"~~ ✅ hecho (2026-08-22)
`ApiClient` convierte los fallos de transporte en tipos propios con mensaje
presentable y añade timeout (20 s; 60 s al subir fotos). `ErrorStateView`
compartida, con texto distinto según sea red o servidor. Aplicada en
Quedadas, Matches y Discovery.

### 15. El chat sondea cada 4 segundos
Se come batería y datos. Ahora que las notificaciones llegan solas, ese ritmo
ya no se justifica: lo barato es subir el intervalo; lo bueno, WebSockets.

### 16. El bucle del producto ya se cierra ✅ (2026-08-22)
Tras una quedada pasada se pregunta si se jugó, el resultado (sólo tenis) y
si repetiría — tabla `SessionFeedback`, una fila por persona y quedada.
**Esto es lo que desbloquea el rating calculado**: ya hay partidos que
puntuar. Elo/Glicko deja de estar bloqueado por falta de datos y pasa a ser
sólo una decisión de algoritmo.

### 17. El icono de la barra de notificaciones sale como silueta blanca
Android exige un icono monocromo ahí y, al no dárselo, aplasta el del
lanzador. Se genera con el mismo `tool/gen_app_icon.dart` y se declara en el
manifest.

---

## Lo que necesita algo tuyo (empezar por aquí)

| Qué | Para qué sirve | Coste |
|---|---|---|
| **Decidir el applicationId** | Bloqueo #1. Irreversible tras publicar | Gratis, pero definitivo |
| **Generar el keystore** | Bloqueo #2. Guardarlo con copia de seguridad | Gratis |
| **Comprar un dominio** | Resuelve de golpe: política de privacidad alojada, verificación de email (#9) y una URL decente para la API | ~10 €/año |
| **Proyecto de Firebase** | Push de verdad (#8) | Gratis |
| **Cuenta de Google Play** | Publicar | 25 $, pago único |
| **Cuenta Apple Developer** | Sólo si algún día hay iOS | 99 $/año |

**Todo lo demás se puede hacer sin esperar a nada**: nombre e icono, quitar
los botones muertos y la pantalla fantasma, rate limiting, revisión de
reportes, tests, estado de "sin conexión" y WebSockets.

## Orden sugerido

1. **applicationId + keystore.** Es lo único irreversible; decidirlo antes de
   que haya usuarios.
2. **Nombre, icono, botones muertos, pantalla fantasma.** Media tarde, y
   cambia por completo la primera impresión.
3. **Dominio.** Desbloquea tres cosas a la vez por 10 €.
4. **Firebase y push.** Es lo que más cambia el uso real.
5. **Rate limiting + revisión de reportes.** Lo que hace falta para dejar
   entrar a gente que no conoces.
6. **Tests**, antes de que la app tenga usuarios a los que romperle algo.
