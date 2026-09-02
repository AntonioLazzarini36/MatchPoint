/// Los enlaces "legales y de contacto" de la app, en un solo sitio.
///
/// Están aquí y no escritos en la pantalla de Ajustes porque **las mismas
/// direcciones viven fuera del código**: en la ficha de Google Play (política
/// de privacidad y borrado de cuenta son campos obligatorios del formulario,
/// ver `docs/play-listing.md`) y en el pie de las propias páginas. Tenerlas
/// repartidas por widgets es cómo acaba una app enlazando a una versión y la
/// tienda a otra.
///
/// Se sirven desde GitHub Pages, no desde `matchpointtenis.es`: el dominio
/// hoy sólo tiene el correo configurado, y un enlace legal que no abre es
/// peor que uno feo.
library;

const _base = 'https://antoniolazzarini36.github.io/MatchPoint';

/// Qué datos guardamos y para qué. Obligatoria en la ficha de Play.
const privacyPolicyUrl = '$_base/privacidad.html';

/// Las condiciones de uso.
const termsUrl = '$_base/terminos.html';

/// Cómo pedir que se borre la cuenta. Play la exige a toda app con registro,
/// y tiene que ser accesible **sin haber entrado**, para quien ya no puede.
const deleteAccountUrl = '$_base/eliminar-cuenta.html';

/// El buzón de la app.
const contactEmail = 'hola@matchpointtenis.es';

/// El enlace de "escríbenos", con el asunto ya puesto.
///
/// El asunto lo rellenamos nosotros por una razón práctica: lo que llega a
/// ese buzón va a ser una mezcla de dudas, fallos e ideas, y sin una marca
/// común no hay forma de separar lo que viene de la app de lo demás. Quien
/// escribe no tiene por qué encargarse de eso.
///
/// El cuerpo va vacío a propósito. Se probó dejar una plantilla ("Qué
/// esperabas / qué pasó") y es justo la clase de formulario que hace que
/// alguien con una frase suelta que decir cierre el correo y no escriba.
Uri contactMailto(String subject) => Uri(
  scheme: 'mailto',
  path: contactEmail,
  queryParameters: {'subject': subject},
);
