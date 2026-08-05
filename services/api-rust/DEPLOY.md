# Desplegar MatchPoint en Railway

Guía concreta para sacar el backend del portátil. Lo que hay que entender
antes de empezar: **mover sólo la base de datos a la nube no sirve de
nada** — si la API sigue corriendo en tu PC, ningún otro dispositivo puede
entrar. Lo que se despliega es **la API y la base juntas**.

Todo lo que se puede automatizar ya está en el repo (`Dockerfile`,
`railway.json`, migraciones dentro del binario). Lo de abajo es lo que hay
que pulsar a mano una vez.

---

## 1. Genera los secretos (en tu máquina, antes de nada)

Nunca reutilices los del repo: están publicados, así que cualquiera podría
firmar tokens válidos. El backend **se niega a arrancar** con ellos si
`APP_ENV=production`.

```bash
openssl rand -base64 48   # JWT_ACCESS_SECRET
openssl rand -base64 48   # JWT_REFRESH_SECRET
openssl rand -base64 32   # MESSAGE_KEY_BASE64
```

> ⚠️ `MESSAGE_KEY_BASE64` cifra los mensajes del chat. Si la cambias más
> adelante, **todos los mensajes ya guardados quedan ilegibles para
> siempre**. Guárdala donde no se pierda.

Si vas a arrancar en producción con la base vacía, da igual la que uses.
Si algún día migras los datos de dev, tiene que ser **la misma** que usaste
en dev.

## 2. Crea el proyecto

1. Entra en railway.app y crea proyecto desde tu repo de GitHub.
2. En el servicio → **Settings → Root Directory**: `services/api-rust`.
   Sin esto intenta construir desde la raíz del monorepo y no encuentra el
   `Dockerfile`.
3. Railway detecta `railway.json` y usa el `Dockerfile`, con healthcheck
   en `/health`.

## 3. Añade Postgres

En el proyecto → **New → Database → PostgreSQL**. Railway crea la variable
`DATABASE_URL` y la comparte con el servicio. No hay que copiarla a mano;
si el servicio no la ve, enlázala desde **Variables → Add Reference**.

**No hace falta correr las migraciones**: el binario las lleva dentro y
las aplica al arrancar (`src/migrate.rs`). En el log de despliegue verás
`migraciones: aplicada ...` la primera vez.

## 4. Variables de entorno

En el servicio → **Variables**:

| Variable | Valor |
|---|---|
| `APP_ENV` | `production` |
| `JWT_ACCESS_SECRET` | el que generaste |
| `JWT_REFRESH_SECRET` | el que generaste |
| `MESSAGE_KEY_BASE64` | el que generaste |
| `TRUST_PROXY` | `true` |
| `PUBLIC_BASE_URL` | la URL pública del servicio (paso 5) |
| `CORS_ALLOWED_ORIGINS` | de dónde se usa la app (paso 6) |
| `PHOTOS_DIR` | `/app/uploads` |
| `RESEND_API_KEY` | tu key de Resend |
| `EMAIL_FROM` | `MatchPoint <onboarding@resend.dev>` |

`PORT` lo inyecta Railway solo — no la pongas.

Con `APP_ENV=production`, si falta o está mal alguna de estas el servicio
**no arranca** y el log dice exactamente cuál. Es a propósito: mejor un
fallo ruidoso al desplegar que un servicio en pie con secretos públicos.

## 5. Dominio y `PUBLIC_BASE_URL`

**Settings → Networking → Generate Domain**. Te da algo tipo
`https://matchpoint-api-production.up.railway.app`.

Copia esa URL en `PUBLIC_BASE_URL` (**sin barra final**). Es la base con la
que se construyen las URLs de las fotos: si se queda en localhost, cada
móvil intentará cargarlas de sí mismo y no se verá ninguna.

## 6. `CORS_ALLOWED_ORIGINS`

Sólo importa para la versión web. Separado por comas, sin barra final:

```
https://tu-web.pages.dev
```

Si de momento sólo usas la app móvil, pon ahí la URL del propio backend:
CORS no aplica a peticiones que no vienen de un navegador, pero la
variable no puede quedar vacía en producción.

## 7. Volumen para las fotos ⚠️

**Esto es obligatorio y es lo que más fácil se olvida.** El sistema de
ficheros de un contenedor se borra en cada despliegue: sin volumen, cada
vez que subas una versión **todo el mundo pierde sus fotos** (y los
perfiles dejan de aparecer en Discovery, que exige al menos una).

Servicio → **Settings → Volumes → Add Volume**, punto de montaje
`/app/uploads`. Que coincida con `PHOTOS_DIR`.

## 8. Apunta la app al backend

```bash
flutter build web --release --dart-define=API_BASE_URL=https://tu-servicio.up.railway.app
flutter build apk --release --dart-define=API_BASE_URL=https://tu-servicio.up.railway.app
```

Sin `--dart-define` la app sigue apuntando a `localhost`, que en un móvil
es el propio móvil.

## 9. Comprueba que va

```bash
curl https://tu-servicio.up.railway.app/health
# {"ok":true}  -> la API responde Y la base de datos contesta
```

`/health` consulta la base de verdad, así que un 200 aquí significa que
las dos cosas están vivas. Si devuelve 503, la API está en pie pero no
llega a Postgres.

Y `https://tu-servicio.up.railway.app/docs` te da el Swagger con toda la
API.

## 10. Datos de prueba (opcional)

`datagen` no está en la imagen: sólo se compila el binario principal. Para
sembrar perfiles falsos en la base de la nube, desde tu máquina:

```bash
cd services/api-rust
DATABASE_URL="<la DATABASE_URL pública de Railway>" cargo run --bin datagen
```

Railway da una URL pública aparte de la interna para conectarse desde
fuera (**Postgres → Connect → Public Network**).

---

## Lo que sigue faltando

- **Verificación de email a otras personas.** Resend, sin dominio
  verificado, sólo entrega al correo con el que creaste la cuenta. Para
  que le llegue a un usuario cualquiera hay que verificar un dominio
  propio (registros DNS).
- **Rate limiting con varias instancias.** El limitador guarda las IPs en
  memoria del proceso: con N réplicas el límite efectivo es N veces el
  configurado. Con una instancia, correcto.
- **Backups.** Railway hace snapshots según el plan; compruébalo antes de
  que haya datos que duela perder.
