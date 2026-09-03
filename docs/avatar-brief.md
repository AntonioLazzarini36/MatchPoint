# Encargo de los avatares

Los seis dibujos que puede elegir quien no quiere subir una foto suya
(`apps/mobile/assets/avatars/character1..6.jpg`, listados en `kAvatarAssets`).

**Los nombres de fichero son fijos.** Sobrescribiendo los seis con los mismos
nombres no hay que tocar ni una línea de código.

## Por qué se rehicieron

Los originales tenían **dos estéticas mezcladas**: el 4 y el 5 eran
fotorrealistas (poros, barba incipiente) y el 1 y el 6 dibujo animado. Dos
problemas:

1. **El estilo se correlacionaba con la etnia.** Los dos avatares no blancos
   eran los dos caricaturescos y los fotorrealistas eran todos blancos. Nadie
   lo hizo a propósito y se ve igual.
2. **Un avatar fotorrealista se confunde con una foto real.** En una app donde
   quedas en persona con un desconocido, eso es peor que feo: el dibujo dice
   de un vistazo "esta persona no ha puesto foto", y la foto falsa no.

Por eso el estilo común es **dibujo animado**, y no al revés.

Aparte, el `character6` original llevaba un **logo de Nike** en la camiseta.
Distribuir una marca registrada en los recursos de la app es un riesgo que no
hay motivo para correr.

## Requisitos técnicos

- **16:9 apaisado**, mínimo 1200 px de ancho. Los originales: 1344×768.
- JPG, nombres `character1.jpg` … `character6.jpg`.
- **La cara grande y centrada.** En Descubrir la miniatura son 84×63 px.
- Fondo de un color liso y **distinto en cada uno**: los seis se ven juntos en
  una rejilla y el color es lo que los separa.
- Sin logos, sin texto, sin marcas de agua.

## El texto para la IA

Se adjunta uno de los avatares existentes como referencia de estilo y se piden
**de uno en uno**: pedidos de golpe, los generadores derivan el estilo entre
imagen e imagen, que es exactamente cómo se llegó a tener dos estéticas.

```
Use the attached image as the exact style reference.

STYLE — match the reference precisely:
- 3D cartoon illustration, stylised, not photorealistic
- Head-and-shoulders portrait, facing straight forward, centred
- Smooth simplified features, large expressive eyes, warm friendly
  expression with a slight smile
- Soft even lighting, no hard shadows
- Flat single-colour background: no gradients, no scenery, no texture
- Plain athletic top (tank top or t-shirt), solid colours

HARD RULES:
- No logos, no brand marks, no sponsor symbols on the clothing
- No text, no watermarks, no signature anywhere in the image
- 16:9 landscape orientation, at least 1200px wide
- The head must fill a good part of the frame: this is shown as a small
  thumbnail, so a small head is unreadable

Generate six separate images, one per person, each on its own flat
background colour:

1. Black man, short curly hair, clean-shaven — background: warm pink
2. White woman, brown hair in a ponytail — background: mid blue
3. East Asian woman, straight dark hair — background: light sky blue
4. Latino man, dark wavy hair, short beard — background: green
5. Middle Eastern man, dark hair, light stubble — background: orange
6. Black woman, natural hair in an updo — background: yellow

Keep all six visibly the same style, the same lighting and the same
framing, so they read as one set.
```

## Dónde generarlas

**Adobe Firefly** es la opción sensata: está entrenada con contenido licenciado
y Adobe cubre el uso comercial. Estas imágenes se distribuyen dentro de una app
publicada, así que la licencia importa tanto como el resultado.

ChatGPT y Gemini son más cómodas para iterar hablando; Midjourney da la mejor
calidad y `--sref` fija el estilo, pero necesita Discord y suscripción.

Evitar los generadores gratuitos tipo Bing Image Creator: la calidad da el
pego, pero los términos de uso comercial son más turbios, y aquí no se está
mirando una imagen, se está redistribuyendo.
