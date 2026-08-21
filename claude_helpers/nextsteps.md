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
- **Moderar** → ❌ nadie revisa esos reportes (ver punto 7)
- **Bloquear** → ⚠️ se quitó Block a propósito (unmatch + report se
  consideraron suficientes). El unmatch corta el contacto, así que
  probablemente cumple, pero conviene tenerlo claro antes de que lo
  pregunten en la revisión.

---

## 🟠 Lo que rompería la experiencia con usuarios reales

### 7. Los reportes no los revisa nadie
`POST /users/:id/report` escribe una fila en una tabla que **nunca se
consulta**. Con usuarios de verdad eso deja de ser deuda técnica y pasa a ser
un problema legal y humano.

Lo mínimo: una consulta SQL documentada. Lo razonable: un endpoint de
administración protegido.

### 8. Sin notificaciones push de verdad
El chat sondea cada 4 s y los contadores cada 15 s, **sólo con la app
abierta**. Con la app cerrada no llega nada — y en una app para quedar, eso
la mata: te escriben para jugar el sábado y te enteras el lunes.

Necesita un proyecto de Firebase (`google-services.json`) para FCM.

### 9. Verificación de email desactivada
`EMAIL_VERIFICATION_ENABLED=false` mientras no haya dominio de correo. Con
esto apagado, cualquiera se registra con el email de otra persona. Ver la
sección de dominio abajo: se enciende sin publicar versión nueva.

### 10. Rate limiting sólo en los endpoints de auth
`/swipes`, `POST /me/photos`, `POST /chats/:id/messages` y
`POST /users/:id/report` no tienen ningún límite. Un usuario autenticado
puede llenar el disco de fotos o spamear mensajes sin freno.

Además, el limitador guarda las IPs **en memoria del proceso**: con varias
instancias el límite efectivo se multiplica por N. Con una, correcto.

### 11. Cobertura de tests casi nula
10 tests en el backend y 1 widget test de plantilla en el móvil. Para algo
que se actualiza y se publica, es poco. La rama `test/full-app-suite` está
creada y vacía.

---

## 🟡 Pulido que se nota al usarla

### 12. ~~Botones muertos en la pantalla de bienvenida~~ ✅ hecho (2026-08-21)
Quitados. Vuelven cuando el login social funcione de verdad.

### 13. ~~Pantalla fantasma~~ ✅ hecho (2026-08-21)
`/partner` borrada entera: ruta, import y archivo.

### 14. Sin manejo de "no hay conexión"
Cada pantalla falla a su manera cuando se cae la red. Falta un estado común.

### 15. El chat sondea cada 4 segundos
Se come batería y datos. Con WebSockets sería una fracción, y además llegaría
al instante.

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
