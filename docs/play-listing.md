# Ficha de Google Play — textos y respuestas

Todo lo que hay que pegar en Play Console, ya redactado. Se mantiene aquí y no
en una nota suelta porque cada versión nueva vuelve a pedir lo mismo, y porque
varias de estas respuestas **tienen que seguir siendo verdad**: la de Seguridad
de los datos describe lo que hace el código, así que cambiar el código sin
volver aquí es lo que convierte una declaración correcta en una falsa.

---

## 1. Crear aplicación

| Campo | Valor |
|---|---|
| Nombre de la aplicación | `MatchPoint Tenis` |
| Nombre del paquete | `es.matchpoint.tenis` |
| Idioma predeterminado | **Español (España) – es-ES** |
| Aplicación o juego | Aplicación |
| Gratis o de pago | Sin coste |

El idioma predeterminado viene puesto en inglés y hay que cambiarlo: es la
ficha que ve quien no encaja en ninguna traducción, y la que lee el revisor.

**El nombre visible se puede cambiar luego; el nombre del paquete, nunca.**

---

## 2. Categoría

**Deportes.**

Merece una nota, porque hay una tentación de poner «Social» o «Citas» y sería
un error caro. Esta app empareja gente para **jugar al tenis**: el nivel, el
horario y el resultado del partido son el producto entero. Play aplica a las
apps de citas un régimen aparte (requisitos extra de verificación y de
moderación) que aquí no toca, y meterse en él por describirse mal es trabajo y
riesgo a cambio de nada.

Lo único que un revisor podría leer como «citas» es el **filtro de género** de
Descubrir. Está para que quien no quiera jugar con desconocidos del otro sexo
pueda decirlo, igual que en cualquier club, y por eso la descripción deja el
propósito sin ambigüedad desde la primera frase.

Etiquetas sugeridas: `Tenis`, `Deportes de raqueta`, `Comunidad deportiva`.

---

## 3. Descripción breve (máx. 80 caracteres)

**Español** (71):

```
Encuentra con quién jugar al tenis cerca de ti, a tu nivel y a tu hora.
```

**Inglés** (62):

```
Find tennis partners near you, at your level, when you're free.
```

---

## 4. Descripción completa (máx. 4000 caracteres)

### Español

```
Tienes con qué jugar y no tienes con quién. MatchPoint es para eso y para nada más.

Dices dónde juegas, qué nivel tienes y qué días y horas sueles tener libres. La app te enseña a la gente de tu zona con la que coincides de verdad: primero quien ya te ha dado a "jugar", después quien comparte tus huecos en la semana, después quien encaja con lo que buscas, y por último quien está más cerca.

CÓMO FUNCIONA

1. Rellenas tu perfil: tu zona, tu nivel y tu horario semanal en una rejilla de siete días por tres franjas.
2. Buscas. Ves a quién tienes cerca, con las franjas que compartís señaladas y la distancia en kilómetros.
3. Cuando dos personas se eligen, se abre una conversación.
4. Desde el chat propones un día, una hora y un sitio. La otra persona acepta o propone otra cosa.
5. Después del partido, la app os pregunta qué tal fue.

POR QUÉ ESE ÚLTIMO PASO IMPORTA

En cualquier app de este tipo el nivel se lo pone cada uno, y todo el mundo se pone un poco por encima. Aquí, después de jugar, cada uno dice qué nivel le vio al otro. Si varias personas coinciden en que alguien está por encima o por debajo de lo que declara, aparece en su perfil. También en el tuyo: no es una medalla, es un aviso, y si cinco personas creen que exageras tu nivel, la primera que tiene que saberlo eres tú.

TAMBIÉN

- Mapa de clubes y pistas de tenis cerca de la ubicación que elijas.
- Aviso el día antes de un partido acordado.
- Español e inglés, cambiable en cualquier momento.
- Chat con los mensajes cifrados en nuestra base de datos.

SOBRE TU UBICACIÓN

MatchPoint no usa el GPS del móvil. Eliges tu zona a mano, en un mapa, y lo que ven los demás es el nombre del municipio y la distancia aproximada en kilómetros. Tus coordenadas no salen del servidor.

GRATIS

Sin suscripción, sin compras dentro de la aplicación y sin anuncios.

MatchPoint no reserva pistas ni tiene convenio con ningún club: eso lo seguís organizando vosotros, como hasta ahora. Lo que resuelve es la parte difícil, que es encontrar a la otra persona.

Política de privacidad: https://antoniolazzarini36.github.io/MatchPoint/privacidad.html
```

### Inglés

```
You have a racket and nobody to play with. That is the only problem MatchPoint solves.

You say where you play, what level you are, and which days and times you are usually free. The app shows you people near you that you actually overlap with: first whoever already picked you, then whoever shares your slots in the week, then whoever fits what you are looking for, and last whoever is closest.

HOW IT WORKS

1. Fill in your profile: your area, your level and your weekly availability on a seven-day, three-band grid.
2. Browse. See who is near you, with the slots you share highlighted and the distance in kilometres.
3. When two people pick each other, a conversation opens.
4. From the chat you propose a day, a time and a place. The other person accepts or proposes something else.
5. After the match, the app asks how it went.

WHY THAT LAST STEP MATTERS

In every app like this, people set their own level, and everyone rounds up. Here, after playing, each of you says what level you thought the other one was. If several people agree that someone is above or below what they claim, it shows on their profile. Yours included: it is a warning, not a badge, and if five people think you overstate your level, you are the first one who should know.

ALSO

- A map of tennis clubs and courts near the location you choose.
- A reminder the day before an agreed match.
- Spanish and English, switchable at any time.
- Chat messages encrypted in our database.

ABOUT YOUR LOCATION

MatchPoint does not use your phone's GPS. You pick your area by hand on a map, and what others see is the name of the town and the approximate distance in kilometres. Your coordinates never leave the server.

FREE

No subscription, no in-app purchases, no ads.

MatchPoint does not book courts and has no agreement with any club: you still arrange that yourselves. What it solves is the hard part, which is finding the other person.

Privacy policy: https://antoniolazzarini36.github.io/MatchPoint/privacidad.html
```

---

## 5. Gráficos

| Recurso | Estado | Dónde está |
|---|---|---|
| Icono 512×512 | Hecho | `apps/mobile/play/icon_512.png` |
| Imagen destacada 1024×500 | Hecho | `apps/mobile/play/feature_graphic.png` |
| Capturas de teléfono (mín. 2, máx. 8) | **Pendiente** | — |

Los dos primeros los genera `dart run tool/gen_play_assets.dart` desde el icono
de la app, así que no se desincronizan con la marca.

**Capturas sugeridas**, en este orden — la primera es la que más se mira:

1. Descubrir, con dos o tres personas y las franjas compartidas marcadas.
2. Un perfil abierto, enseñando nivel, horario y partidos jugados.
3. El chat con una propuesta de partido dentro.
4. La rejilla de disponibilidad.
5. El mapa de clubes.

---

## 6. Acceso a la aplicación

**Esto no es opcional y es donde más apps se atascan.** MatchPoint no enseña
nada sin cuenta, así que hay que darle credenciales al revisor o rechazan la
versión por «no se puede probar».

Hay que crear una cuenta dedicada para revisión y pegar usuario y contraseña
en «Acceso a la aplicación» → «Todas las funciones están restringidas».

**Y hay una trampa que hay que resolver a la vez:** con
`DEMO_SEED_NEW_USERS` apagado (ver punto 9), una cuenta recién creada entra a
una aplicación **vacía** — sin nadie a quien descubrir y sin conversaciones. Un
revisor que ve eso concluye que la app no funciona.

La salida no es volver a encender el sembrado para todo el mundo, sino que la
cuenta de revisión esté **ubicada donde ya hay perfiles de prueba**:

```powershell
cd services/api-rust
# perfiles de prueba en una ciudad concreta
cargo run --bin datagen
# y la cuenta del revisor, en esa misma ciudad
cargo run --bin datagen -- --me review@matchpointtenis.es <contrasena> "Revision Google" "Benalmadena"
```

En las instrucciones de acceso conviene decirlo tal cual, en inglés:

```
This account is located in Benalmádena, Spain, where test profiles exist so the
discovery feed is not empty. The app is location-based: accounts created in
other areas will show no results, which is expected behaviour and not a bug.
Set your area to Benalmádena in onboarding to see the same content.
```

Ser transparente con esto es lo correcto y además lo que evita el rechazo: los
datos de prueba para revisión son normales; el problema de política sería
enseñar perfiles falsos a **usuarios reales**.

---

## 7. Clasificación del contenido (cuestionario IARC)

| Pregunta | Respuesta |
|---|---|
| Categoría | Red social / comunicación |
| ¿Los usuarios interactúan o se comunican entre sí? | **Sí** — chat entre personas emparejadas |
| ¿Pueden compartir su ubicación con otros usuarios? | **Sí** — el sitio de un partido propuesto |
| ¿Pueden compartir información personal? | **Sí** — texto libre en perfil y chat |
| ¿Contenido generado por usuarios sin moderar? | No — hay denuncia y cola de moderación |
| Violencia, sexo, drogas, lenguaje soez, terror | No a todo |
| Juegos de azar o apuestas | No |
| Compras digitales | No |

Si preguntan por las salvaguardas de contenido de usuario, las tres existen y
conviene nombrarlas: **denunciar** a una persona (con motivo), **deshacer el
match** (corta el contacto por los dos lados) y una **cola de moderación** que
revisa una persona.

---

## 8. Seguridad de los datos

Nada de esto se comparte con terceros. Firebase y el proveedor de correo
tratan datos **por nuestra cuenta** como encargados, que en la clasificación de
Play no es «compartir».

| Tipo | ¿Se recoge? | Vinculado al usuario | Obligatorio | Para qué |
|---|---|---|---|---|
| Nombre | Sí | Sí | Sí | Funciones de la app |
| Correo electrónico | Sí | Sí | Sí | Gestión de la cuenta |
| Identificadores de usuario | Sí | Sí | Sí | Gestión de la cuenta |
| Otra información personal (fecha de nacimiento, género, nivel) | Sí | Sí | La fecha sí; el género no | Funciones de la app |
| Ubicación aproximada | Sí | Sí | Sí | Funciones de la app |
| Fotos | Sí | Sí | Sí | Funciones de la app |
| Otros mensajes dentro de la app | Sí | Sí | Sí | Funciones de la app |
| Interacciones con la app | Sí | Sí | No | Analíticas |
| ID de dispositivo | Sí | Sí | No | Notificaciones |

**Ubicación: «aproximada», no «precisa».** La app no pide permiso de ubicación
ni lee el GPS — se elige un punto a mano. Y lo que sale hacia otros usuarios es
el municipio y una distancia; las coordenadas se quedan en el servidor.

**ID de publicidad: no.** El permiso lo metía `firebase_analytics` al fusionar
su manifest; se elimina a propósito en `AndroidManifest.xml` para que esta
respuesta pueda ser «no». Si algún día se vuelve a colar, esta casilla se
vuelve mentira — se comprueba con:

```bash
unzip -p app-release.aab base/manifest/AndroidManifest.xml | strings | grep AD_ID
```

Prácticas de seguridad, todas ciertas:

- Datos cifrados en tránsito: **sí** (HTTPS).
- El usuario puede pedir que se borren sus datos: **sí**.
- URL de borrado de cuenta:
  `https://antoniolazzarini36.github.io/MatchPoint/eliminar-cuenta.html`

---

## 9. Antes de enviar a revisión

- [ ] **Apagar `DEMO_SEED_NEW_USERS` en Railway.** Con esto encendido, cada
      persona que se registra recibe compañeros, mensajes y partidos falsos.
      Para enseñar la app en un club vale; para usuarios reales es
      tergiversación y es motivo de suspensión.
- [ ] Crear la cuenta de revisión y ponerla donde hay perfiles (punto 6).
- [ ] Subir `app-release.aab` (45,3 MB), no el APK.
- [ ] Enlazar política de privacidad, términos y borrado de cuenta.
- [ ] Público objetivo: **18 años o más** — deja fuera todo el régimen de
      Familias, que no aplica a una app para quedar a jugar entre adultos.
- [ ] Comprobar que la app instalada desde el AAB llega al servidor
      (`API_BASE_URL` dentro del binario, ver CLAUDE.md).

---

## 10. Enlaces

| Qué | URL |
|---|---|
| Política de privacidad | https://antoniolazzarini36.github.io/MatchPoint/privacidad.html |
| Términos de uso | https://antoniolazzarini36.github.io/MatchPoint/terminos.html |
| Borrado de cuenta | https://antoniolazzarini36.github.io/MatchPoint/eliminar-cuenta.html |
| Correo de contacto | hola@matchpointtenis.es |
