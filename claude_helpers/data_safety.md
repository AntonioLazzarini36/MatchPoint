# Formulario de Data Safety de Google Play — qué contestar

Escrito el 2026-08-27, a partir de lo que la app **hace de verdad** (no de lo
que nos gustaría). Play compara este formulario con la política de privacidad
publicada: si no cuadran, rechaza la ficha. Cualquier cambio en uno hay que
hacerlo en el otro (`docs/privacidad.html`).

## Lo primero, y lo que más se falla

- **¿Se cifran los datos en tránsito?** → **Sí.** La API va por HTTPS
  (Railway termina TLS).
- **¿Puede el usuario pedir que se borren sus datos?** → **Sí**, y hay que dar
  la URL o explicar el mecanismo: está dentro de la app, Ajustes → Borrar
  cuenta (`DELETE /me`). Play comprueba este punto específicamente.
- **¿Se recogen datos?** → **Sí.** Decir que no con una app que pide correo y
  fotos es la forma más rápida de que te tumben la ficha.
- **Recogido vs. compartido:** «compartido» en el vocabulario de Play significa
  transferido a un *tercero*. Los proveedores que sólo procesan por cuenta
  nuestra (Railway, Firebase) **no** cuentan como compartir. Aquí no se
  comparte nada con nadie.

## Tabla de datos

| Categoría de Play | ¿Se recoge? | Obligatorio | Para qué (según su lista) |
|---|---|---|---|
| Correo electrónico | Sí | Sí | Gestión de la cuenta |
| Nombre | Sí | Sí | Gestión de la cuenta, funciones de la app |
| Identidad de género | Sí | **No** | Funciones de la app (filtro) |
| Fecha de nacimiento | Sí | Sí | Funciones de la app (edad y filtro por edad) |
| Ubicación aproximada | Sí | Sí | Funciones de la app |
| Fotos | Sí | Sí | Funciones de la app |
| Mensajes en la app | Sí | No | Funciones de la app |
| Otra información personal | Sí | No | Nivel, club, logros y horario habitual |
| Identificadores del dispositivo | Sí | No | Notificaciones push |
| Interacciones con la app | Sí | No | Analítica |
| Diagnósticos / fallos | Sí | No | Analítica |

**Ninguna categoría se marca como compartida.** Todas se marcan como
recogidas, cifradas en tránsito y borrables.

### Detalle de la ubicación

Marcar **«ubicación aproximada»**, nunca «precisa». Es correcto y conviene
saber por qué: la app **no pide permiso de GPS** — la persona escribe su código
postal o elige el municipio, y lo que se guarda son las coordenadas de ese
sitio. Además, de ahí sólo sale hacia otros usuarios la **distancia en km**,
nunca las coordenadas. Si algún día se añade GPS real, esta respuesta cambia y
también la política.

## Contenido generado por usuarios

Play exige tres cosas a las apps donde la gente sube contenido y habla entre
sí. Estado hoy:

- **Denunciar** → ✅ `POST /users/:id/report`, botón en el perfil.
- **Moderar** → ✅ cola en `GET /admin/reports`, cerrada con `PATCH`.
- **Bloquear** → ⚠️ no existe como tal. Se quitó a propósito: deshacer el
  compañero corta el contacto por completo y denunciar lo manda a revisión.
  Probablemente cumple, pero **es el punto por el que más fácil pregunten en la
  revisión**, así que conviene tener la respuesta preparada — o añadir Bloquear
  antes de mandarla, que es media tarde de trabajo.

Hay que declarar además que la app tiene contenido generado por usuarios y
describir cómo se modera.

## 🔴 Antes de subirla a producción: quitar los perfiles falsos

Ahora mismo producción está sembrada con 10 perfiles inventados
(`@example.com`) y `DEMO_SEED_NEW_USERS=true`, que engancha compañeros y
partidos falsos a cada cuenta nueva. **Eso es correcto para un prototipo que se
enseña a mano, y es un problema serio en una app publicada**: Play lo trata
como comportamiento engañoso, y a una persona real que se descarga la app le
estás prometiendo gente que no existe.

Antes de publicar:

1. `DEMO_SEED_NEW_USERS=false` (o quitar la variable) en Railway.
2. Borrar las cuentas sembradas.
3. Comprobar que una cuenta nueva no recibe compañeros.

## Clasificación de contenido

Es un cuestionario aparte del de Data Safety. Al ser una app de contacto entre
personas con chat, saldrá **PEGI 12+ o superior**, y hay que declarar que
permite interactuar y compartir ubicación aproximada con otros usuarios.
