# Páginas públicas (GitHub Pages)

Esta carpeta existe por un motivo concreto: **Google Play no deja publicar sin
una política de privacidad en una URL pública y accesible**, y MatchPoint
recoge correo, fotos y zona, así que no hay excepción posible. Alojarlo aquí es
gratis y no depende de tener dominio todavía.

- `privacidad.html` — política de privacidad
- `terminos.html` — términos de uso

## Antes de dar la URL a nadie

Los dos ficheros llevan un recuadro amarillo con dos huecos por rellenar:
`[NOMBRE DEL RESPONSABLE]` y `[EMAIL DE CONTACTO]`. El RGPD exige identificar
al responsable del tratamiento y dar una vía de contacto — sin eso la página no
cumple, y es justo lo que revisa Play. **Quita también el recuadro amarillo
entero** (`<div class="todo">…</div>`) una vez rellenado: es una nota para ti,
no para quien lea la política.

Conviene una dirección dedicada (`privacidad@tudominio.com`) en vez del correo
personal: esa URL va a ser pública para siempre.

## Cómo publicarlo

En GitHub: **Settings → Pages → Source: Deploy from a branch**, rama la que
uses como principal, carpeta **`/docs`**. En un par de minutos queda en:

```
https://<usuario>.github.io/MatchPoint/privacidad.html
https://<usuario>.github.io/MatchPoint/terminos.html
```

Esa primera URL es la que se pega en la ficha de Play. El día que haya dominio
propio se puede mover, pero **no cambies la URL después de publicar la app** sin
actualizarla también en Play.

## Mantenerlo al día

No es un trámite que se hace una vez. Si se añade algo que recoja datos nuevos
—login con Google, pagos, subir vídeos— hay que actualizar la tabla de
`privacidad.html` **y** el formulario de Data Safety de Play, que tiene que
coincidir con lo que dice la política. Play compara las dos cosas.
