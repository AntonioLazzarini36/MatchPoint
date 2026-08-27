// Convierte el logo de partida (`tool/logo_source.png`) en los PNG que
// necesita `flutter_launcher_icons`. No hay ningún paquete de imágenes de por
// medio: `dart:io` ya trae zlib, que es lo único imprescindible para leer y
// escribir PNG, así que esto se ejecuta en cualquier máquina con el SDK y
// nada más.
//
//   dart run tool/gen_app_icon.dart      # esto
//   dart run flutter_launcher_icons      # reparte los tamaños
//
// Qué le hace al original y por qué:
//
//  0. **Se queda con la raqueta y tira la zapatilla.** El original es un
//     círculo partido: raqueta sobre naranja a la izquierda, zapatilla sobre
//     azul a la derecha. Decía "tenis **y** correr", que era el
//     posicionamiento de la app hasta que dejó de serlo — desde que sólo hay
//     tenis (ver `lib/core/utils/app_sports.dart`), la mitad derecha anuncia
//     algo que no existe, y es lo primero que ve alguien que instala la app.
//     Así que se aísla la raqueta, se **centra** en el círculo y el fondo pasa
//     a ser un naranja liso. El separador blanco desaparece con ella: sin dos
//     mitades no hay nada que separar.
//
//     El dibujo no se rehace a mano ni se recorta a ojo: la máscara del paso 3
//     ya sabe distinguir dibujo de fondo, así que la raqueta sale de ahí, se
//     mide su caja y se coloca por su centro. Volver a exportar el logo a otro
//     tamaño sigue sin obligar a tocar un número.
//
//  1. **Quita el marco, de dos formas distintas según a dónde vaya.** El
//     original es un círculo sobre blanco opaco, que en el escritorio de un
//     móvil se lee como un cuadrado blanco con un círculo dentro.
//     - **Para el lanzador**, las dos mitades se extienden **hasta el borde**.
//       Un icono adaptativo no tiene "fuera": el sistema lo recorta con la
//       forma que quiera y espera que la capa de fondo llene el lienzo. Se
//       probó dejarla transparente por fuera del círculo y HyperOS rellenó
//       el hueco **de negro**, porque la máscara de ese lanzador es un
//       cuadrado redondeado y no un círculo: en el escritorio salía el logo
//       metido en una pastilla negra. Llegando al borde, con máscara redonda
//       se ve el logo circular tal cual, y con cualquier otra la misma
//       división con esa forma — nunca hay relleno, porque no hay hueco.
//     - **Para dentro de la app** (`app_logo.png`) sí se mantiene el círculo
//       recortado con las esquinas transparentes: ahí lo dibuja Flutter
//       sobre el fondo de la pantalla, no lo recorta ningún sistema.
//
//  2. **Recolorea el fondo.** El original venía en naranja `#F4511E`, que es
//     justo el que la app dejó atrás al pasar a la paleta de pista. Se usa el
//     color que la app **ya** usa para el tenis
//     (`lib/core/utils/sport_words.dart`: tierra batida), así que el icono
//     habla el mismo idioma que el resto de la interfaz. Se descartó el verde
//     de marca: en la app significa "acción/estado", no deporte.
//
//  3. **Separa el dibujo del fondo** para poder darle a Android un icono
//     adaptativo de verdad: capa de atrás = el círculo naranja, capa de
//     delante = la raqueta. Es lo que hace que el lanzador pueda moverlas por
//     separado en vez de tratar el icono como una estampa.
//
//  4. **Ajusta el tamaño del dibujo a cada destino.** La capa de delante del
//     icono adaptativo no se dibuja sobre los 108 dp de la capa sino dentro
//     del 68% central, así que lleva su propia escala para acabar viéndose
//     igual de grande que en el icono plano.
//
// La geometría (centro, radio, ancho del separador, colores de cada mitad) se
// **mide** del original en vez de estar escrita a mano, para que volver a
// exportar el logo a otro tamaño no obligue a tocar números aquí.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sourcePath = 'tool/logo_source.png';

/// Color del tenis, copiado de `lib/core/utils/sport_words.dart`.
const _tennis = [0xC6, 0x5F, 0x3B]; // tierra batida
const _white = [0xFF, 0xFF, 0xFF];

/// Cuánto del lienzo ocupa la raqueta por su lado más largo, en el icono del
/// lanzador.
///
/// Es una **fracción del resultado**, no un multiplicador sobre el tamaño que
/// tuviera en el original: la raqueta ya no está donde estaba (se ha sacado de
/// su mitad y se ha centrado), así que "un 25% más grande que antes" dejó de
/// significar nada. La escala se calcula midiendo su caja — ver `_artScaleFor`.
///
/// El número sale de la zona segura del icono adaptativo, que es la más
/// exigente de las tres salidas. La cuenta, en dp de los 108 de la capa:
///
///   la capa de delante se dibuja dentro del 68% central   -> 73,4 dp
///   la raqueta ocupa 0,58/0,68 = 85% de esa capa           -> 62,6 dp
///   Android garantiza no recortar un círculo de            -> 66 dp
///
/// O sea que la punta de la raqueta queda a 31,3 dp del centro, de los 33
/// disponibles. Con 0,62 salían 67 dp, por encima del círculo garantizado, y
/// un lanzador con máscara agresiva podía comerse la punta de la cabeza o el
/// final del mango. En el icono plano y en el logo de dentro de la app sobra
/// sitio, así que manda esta.
const _launcherArtFraction = 0.58;

/// La capa de delante del icono adaptativo se dibuja dentro del **68% central**
/// de la capa (el `<inset android:inset="16%">` que escribe
/// `flutter_launcher_icons`), mientras que la de atrás ocupa los 108 dp
/// enteros. Para que la raqueta acabe viéndose del mismo tamaño que en el
/// icono plano hay que pedirla proporcionalmente más grande dentro de su capa.
const _adaptiveInset = 0.68;

/// Cuánto del lienzo ocupa la raqueta en el icono de notificación. Más que en
/// el lanzador: aquí no hay círculo de fondo del que quedar dentro, y el
/// sistema añade su propio margen alrededor.
const _notificationArtFraction = 0.84;


void main() {
  final src = _decodePng(File(_sourcePath).readAsBytesSync());
  final geo = _measure(src);
  final art = _racket(geo, _artworkMask(src, geo));

  final launcherArtScale = art.scaleFor(geo.size, _launcherArtFraction);
  // La capa de delante se dibuja dentro del 68% central de la suya, así que
  // hay que pedirla más grande para que acabe viéndose igual que en el plano.
  final adaptiveArtScale = launcherArtScale / _adaptiveInset;

  Directory('assets/icon').createSync(recursive: true);

  // --- Icono del lanzador: a sangre, sin nada transparente ---

  // Plano: web, iOS y el icono "de siempre" de Android para móviles
  // anteriores a los adaptativos.
  _write(
    'assets/icon/app_icon.png',
    _compose(geo, art, fill: _Fill.bleed, artScale: launcherArtScale),
  );

  // Capa de atrás del adaptativo: el naranja liso, sin nada encima.
  _write(
    'assets/icon/app_icon_background.png',
    _compose(geo, art, fill: _Fill.bleed, artScale: null),
  );

  // Capa de delante: sólo la raqueta, sobre transparente y con su escala,
  // para caer justo en el centro del círculo que tiene detrás.
  _write(
    'assets/icon/app_icon_foreground.png',
    _compose(geo, art, fill: _Fill.none, artScale: adaptiveArtScale),
  );

  // --- Icono de la barra de notificaciones ---
  //
  // Android lo pinta **monocromo** a 24 dp: coge la silueta y la rellena de
  // un color. Si no se le da uno, aplasta el del lanzador y sale una mancha.
  //
  // Y no vale la raqueta con la zapatilla: se probó, y a 24 dp dos objetos
  // uno al lado del otro dan doce píxeles cada uno — se convierten en dos
  // borrones grises. Ni siquiera cerrando la rejilla de cuerdas se salvaba.
  //
  // Lo que sí funciona a ese tamaño es **la silueta del propio logo**: un
  // círculo partido por su separador. Es una sola forma, se lee de un
  // vistazo, y es exactamente la marca — nadie tiene que reconocer una
  // raqueta de doce píxeles para saber de qué app es.
  final notification = _notificationIcon(geo, art);
  _write('assets/icon/app_icon_notification.png', notification);

  // Y directamente en `res/`, a los tamaños que Android espera: 24 dp en
  // cada densidad. `flutter_launcher_icons` no toca el icono de
  // notificación, así que este es el único sitio de donde puede salir.
  const densities = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96,
  };
  densities.forEach((density, size) {
    final dir = Directory('android/app/src/main/res/drawable-$density');
    dir.createSync(recursive: true);
    _write('${dir.path}/ic_notification.png', _resize(notification, size));
  });

  // --- Logo de dentro de la app: el círculo, con las esquinas transparentes ---

  final circleScale = geo.size / (geo.radius * 2);
  _write(
    'assets/icon/app_logo.png',
    _compose(
      geo,
      art,
      fill: _Fill.circle,
      circleScale: circleScale,
      // Mismo criterio que el icono plano: la raqueta ocupa una fracción del
      // círculo, y aquí el círculo llena el lienzo, así que es la misma
      // fracción del lienzo.
      artScale: launcherArtScale,
    ),
  );

  stdout.writeln(
    'Escritos assets/icon/app_icon{,_background,_foreground}.png y '
    'app_logo.png desde $_sourcePath '
    '(círculo r=${geo.radius.toStringAsFixed(0)}, '
    'raqueta ${art.span.toStringAsFixed(0)} px '
    'centrada en ${art.cx.toStringAsFixed(0)},${art.cy.toStringAsFixed(0)})',
  );
}

/// Reduce una imagen promediando cada bloque de origen.
///
/// Promediar y no coger el píxel más cercano: al bajar de 1024 a 24 el
/// vecino más cercano se come el antialiasing entero y deja el borde
/// escalonado, que en un icono redondo se nota mucho.
_Image _resize(_Image src, int size) {
  final out = Uint8List(size * size * 4);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final x0 = x * src.width ~/ size;
      final x1 = ((x + 1) * src.width ~/ size).clamp(x0 + 1, src.width);
      final y0 = y * src.height ~/ size;
      final y1 = ((y + 1) * src.height ~/ size).clamp(y0 + 1, src.height);

      var a = 0.0;
      var count = 0;
      for (var sy = y0; sy < y1; sy++) {
        for (var sx = x0; sx < x1; sx++) {
          a += src.at(sx, sy)[3];
          count++;
        }
      }

      final i = (y * size + x) * 4;
      // Blanco puro siempre: sólo el alfa define la silueta, y Android va a
      // recolorearla de todas formas.
      out[i] = 255;
      out[i + 1] = 255;
      out[i + 2] = 255;
      out[i + 3] = (a / count).round().clamp(0, 255);
    }
  }

  return _Image(size, size, out);
}

/// El icono de la barra de estado: la raqueta sola.
///
/// Android lo pinta **monocromo** a 24 dp: coge la silueta y la rellena de un
/// color. Si no se le da uno, aplasta el del lanzador y sale una mancha.
///
/// Antes esto era el círculo del logo con el corte del separador, porque a
/// 24 dp la raqueta **y** la zapatilla daban doce píxeles cada una y salían dos
/// borrones. Con un solo dibujo el problema desaparece: la raqueta se lleva los
/// 24 px enteros. Lo que sí sigue sin sobrevivir a ese tamaño es la rejilla de
/// cuerdas —líneas de menos de un píxel, que al reducir se van en gris—, así
/// que la cabeza se **rellena**: se toma la silueta exterior de la raqueta y se
/// pinta maciza. Una raqueta con la cabeza sólida se reconoce a 24 px; una con
/// la cuerda dibujada es una mancha con textura.
_Image _notificationIcon(_Geometry g, _Art art) {
  final n = g.size;
  final scale = art.scaleFor(n, _notificationArtFraction);
  final centre = n / 2.0;
  final px = Uint8List(n * n * 4);

  // Relleno por barrido horizontal: para cada fila, todo lo que quede entre el
  // primer y el último píxel de dibujo es "dentro de la raqueta". Con una
  // silueta convexa por filas —que es lo que es una raqueta: cabeza ovalada y
  // mango— esto cierra la rejilla sin tocar el contorno, y no hace falta ni
  // dilatar ni erosionar, que redondearía las esquinas del mango.
  for (var y = 0; y < n; y++) {
    var first = -1, last = -1;
    final row = Float32List(n);
    for (var x = 0; x < n; x++) {
      final sx = art.cx + (x + 0.5 - centre) / scale;
      final sy = art.cy + (y + 0.5 - centre) / scale;
      final v = _sample(art.mask, n, sx, sy);
      row[x] = v;
      if (v > 0.5) {
        if (first < 0) first = x;
        last = x;
      }
    }

    for (var x = 0; x < n; x++) {
      // Dentro del tramo: opaco. Fuera: el valor de la máscara, que conserva
      // el antialiasing del borde exterior.
      final a = (first >= 0 && x >= first && x <= last) ? 1.0 : row[x];
      final i = (y * n + x) * 4;
      px[i] = 255;
      px[i + 1] = 255;
      px[i + 2] = 255;
      px[i + 3] = (a * 255).round().clamp(0, 255);
    }
  }

  return _Image(n, n, px);
}

/// Qué se pinta de fondo: nada (capa de delante del adaptativo), naranja
/// hasta el borde (icono del lanzador) o el círculo recortado (logo de dentro
/// de la app).
enum _Fill { none, bleed, circle }

/// La raqueta aislada del original, con su caja ya medida.
///
/// `mask` es la máscara del dibujo con la mitad de la zapatilla puesta a cero;
/// `cx`/`cy` son el centro de su caja, que es el punto que hay que hacer
/// coincidir con el centro del lienzo para que quede centrada de verdad. El
/// centroide daría un resultado peor: el mango pesa mucho y tiraría del dibujo
/// hacia abajo, dejando la cabeza descentrada, que es lo que se mira.
class _Art {
  final Float32List mask;
  final double cx, cy, span;

  _Art({
    required this.mask,
    required this.cx,
    required this.cy,
    required this.span,
  });

  /// Cuánto hay que escalarla para que ocupe `fraction` del lienzo por su lado
  /// más largo.
  double scaleFor(int canvas, double fraction) => canvas * fraction / span;
}

/// Se queda con la mitad de la raqueta y mide dónde está.
///
/// El umbral de 0.35 es sólo para **medir** la caja, no para dibujar: la
/// máscara sigue entrando entera en el render, con su antialiasing. Sin él,
/// cualquier píxel de mezcla suelto en el borde del círculo estiraría la caja
/// y la raqueta saldría más pequeña de lo pedido.
_Art _racket(_Geometry g, Float32List full) {
  final n = g.size;
  final mask = Float32List(n * n);
  var minX = n, maxX = -1, minY = n, maxY = -1;

  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      // La raqueta es la mitad izquierda; la derecha es la zapatilla, que se
      // va entera.
      if (x - g.cx >= 0) continue;
      final v = full[y * n + x];
      if (v <= 0) continue;
      mask[y * n + x] = v;
      if (v < 0.35) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < 0) {
    throw StateError('No se encontró la raqueta en $_sourcePath');
  }

  return _Art(
    mask: mask,
    cx: (minX + maxX) / 2,
    cy: (minY + maxY) / 2,
    span: math.max(maxX - minX, maxY - minY).toDouble(),
  );
}

// --- Medir el original ---

class _Geometry {
  final int size;
  final double cx, cy, radius;
  final double dividerHalfWidth;
  final List<int> leftColor, rightColor;

  _Geometry({
    required this.size,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.dividerHalfWidth,
    required this.leftColor,
    required this.rightColor,
  });
}

_Geometry _measure(_Image src) {
  // El círculo es todo lo que no es el blanco del marco.
  var minX = src.width, maxX = 0, minY = src.height, maxY = 0;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (_isWhite(src, x, y)) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  final cx = (minX + maxX) / 2;
  final cy = (minY + maxY) / 2;
  final radius = ((maxX - minX) + (maxY - minY)) / 4;

  // Color de cada mitad = el que más se repite dentro de ella. Buscarlo así
  // y no leyendo un píxel concreto evita depender de dónde cae el dibujo.
  final leftColor = _dominantColor(src, cx, cy, radius, left: true);
  final rightColor = _dominantColor(src, cx, cy, radius, left: false);

  // El separador blanco recorre el círculo entero de arriba abajo, así que a
  // esta altura —por encima de la raqueta y de la zapatilla— es lo único
  // blanco que hay.
  final probeY = (cy - radius * 0.78).round();
  var half = 0.0;
  while (_isWhite(src, (cx + half).round(), probeY)) {
    half += 1;
  }

  return _Geometry(
    size: src.width,
    cx: cx,
    cy: cy,
    radius: radius,
    dividerHalfWidth: half,
    leftColor: leftColor,
    rightColor: rightColor,
  );
}

List<int> _dominantColor(
  _Image src,
  double cx,
  double cy,
  double radius, {
  required bool left,
}) {
  final counts = <int, int>{};
  for (var y = (cy - radius).round(); y < cy + radius; y++) {
    for (var x = (cx - radius).round(); x < cx + radius; x++) {
      final dx = x - cx, dy = y - cy;
      if (dx * dx + dy * dy > (radius - 6) * (radius - 6)) continue;
      if (left ? dx > -radius * 0.1 : dx < radius * 0.1) continue;
      final p = src.at(x, y);
      final key = (p[0] << 16) | (p[1] << 8) | p[2];
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  var best = 0, bestCount = -1;
  counts.forEach((k, v) {
    if (v > bestCount) {
      bestCount = v;
      best = k;
    }
  });
  return [(best >> 16) & 0xFF, (best >> 8) & 0xFF, best & 0xFF];
}

/// Cuánto de "dibujo" hay en cada píxel, de 0 a 1.
///
/// El dibujo es blanco puro sobre un fondo de un solo color, así que todo
/// píxel del original es `fondo + t·(blanco − fondo)`: proyectar sobre esa
/// recta da `t` directamente, y de paso sale el antialiasing del original
/// gratis, sin umbrales ni bordes dentados.
Float32List _artworkMask(_Image src, _Geometry g) {
  final mask = Float32List(src.width * src.height);
  // Un margen hacia dentro del borde: los píxeles del filo del círculo son
  // una mezcla con el blanco del marco y, sin esto, se colarían en la máscara
  // y dibujarían un aro blanco de un píxel alrededor de todo.
  final rInner = g.radius - 3;
  // El separador se pinta aparte, a lo alto de todo el lienzo, así que aquí
  // se excluye: si entrara en la máscara, en el icono adaptativo se
  // dibujaría dos veces y a dos escalas distintas.
  final excl = g.dividerHalfWidth + 4;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final dx = x - g.cx, dy = y - g.cy;
      if (dx * dx + dy * dy > rInner * rInner) continue;
      if (dx.abs() <= excl) continue;

      final bg = dx < 0 ? g.leftColor : g.rightColor;
      final p = src.at(x, y);
      var dot = 0.0, len = 0.0;
      for (var c = 0; c < 3; c++) {
        final axis = 255.0 - bg[c];
        dot += (p[c] - bg[c]) * axis;
        len += axis * axis;
      }
      final t = len == 0 ? 0.0 : (dot / len).clamp(0.0, 1.0);
      mask[y * src.width + x] = t;
    }
  }
  return mask;
}

// --- Componer las salidas ---

_Image _compose(
  _Geometry g,
  _Art art, {
  required _Fill fill,
  required double? artScale,
  double circleScale = 1.0,
}) {
  final n = g.size;
  final px = Uint8List(n * n * 4);
  // Todo se mide desde el centro del lienzo, no desde el del círculo original
  // (que estaba un píxel descentrado): así el resultado queda centrado de
  // verdad, que es lo que importa cuando el sistema lo recorta.
  final centre = n / 2.0;
  final radius = g.radius * circleScale;

  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      // Igual que en el original: se acumula en premultiplicado y se deshace
      // al escribir. Sobre un lienzo transparente —la capa de delante— la
      // mezcla ingenua devolvería el color oscurecido por su propio alfa.
      var pr = 0.0, pg = 0.0, pb = 0.0, pa = 0.0;

      void paint(List<int> color, double alpha) {
        if (alpha <= 0) return;
        final inv = 1 - alpha;
        pr = color[0] * alpha + pr * inv;
        pg = color[1] * alpha + pg * inv;
        pb = color[2] * alpha + pb * inv;
        pa = alpha + pa * inv;
      }

      final dx = x + 0.5 - centre;
      final dy = y + 0.5 - centre;

      if (fill != _Fill.none) {
        // Con `circle`, un píxel de transición en el borde para que no salga
        // dentado; con `bleed`, cobertura 1 en todo el lienzo. Un solo color:
        // sin dos mitades no hay separador que pintar.
        final inside = fill == _Fill.circle
            ? (0.5 - (math.sqrt(dx * dx + dy * dy) - radius)).clamp(0.0, 1.0)
            : 1.0;
        paint(_tennis, inside);
      }

      if (artScale != null) {
        // Deshacer la escala para saber de qué punto del original viene este
        // píxel. Se referencia al **centro de la caja de la raqueta**, no al
        // del círculo: es lo que la saca de su mitad y la deja centrada.
        final sx = art.cx + dx / artScale;
        final sy = art.cy + dy / artScale;
        paint(_white, _sample(art.mask, g.size, sx, sy));
      }

      final i = (y * n + x) * 4;
      if (pa > 0) {
        px[i] = (pr / pa).round().clamp(0, 255);
        px[i + 1] = (pg / pa).round().clamp(0, 255);
        px[i + 2] = (pb / pa).round().clamp(0, 255);
        px[i + 3] = (pa * 255).round().clamp(0, 255);
      }
    }
  }

  return _Image(n, n, px);
}

/// Muestreo bilineal de la máscara. Al escalar hace falta leer entre píxeles;
/// coger el más cercano dejaría el borde de la raqueta escalonado.
double _sample(Float32List mask, int n, double x, double y) {
  final fx = x - 0.5, fy = y - 0.5;
  final x0 = fx.floor(), y0 = fy.floor();
  final tx = fx - x0, ty = fy - y0;
  double at(int px, int py) {
    if (px < 0 || py < 0 || px >= n || py >= n) return 0;
    return mask[py * n + px];
  }

  final top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx;
  final bottom = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx;
  return top * (1 - ty) + bottom * ty;
}

bool _isWhite(_Image src, int x, int y) {
  if (x < 0 || y < 0 || x >= src.width || y >= src.height) return true;
  final p = src.at(x, y);
  return p[0] > 240 && p[1] > 240 && p[2] > 240;
}

// --- PNG ---

class _Image {
  final int width, height;
  final Uint8List rgba;
  _Image(this.width, this.height, this.rgba);

  List<int> at(int x, int y) {
    final o = (y * width + x) * 4;
    return [rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]];
  }
}

_Image _decodePng(Uint8List bytes) {
  var width = 0, height = 0, colorType = 0;
  final idat = BytesBuilder();

  var i = 8; // saltar la firma
  while (i < bytes.length) {
    final len = _readU32(bytes, i);
    final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
    final data = bytes.sublist(i + 8, i + 8 + len);
    if (type == 'IHDR') {
      width = _readU32(data, 0);
      height = _readU32(data, 4);
      if (data[8] != 8) {
        throw StateError('Sólo se admiten 8 bits por canal');
      }
      colorType = data[9];
      if (data[12] != 0) throw StateError('PNG entrelazado no admitido');
    } else if (type == 'IDAT') {
      idat.add(data);
    }
    i += 12 + len;
  }

  final channels = switch (colorType) {
    2 => 3, // RGB
    6 => 4, // RGBA
    _ => throw StateError('Tipo de color $colorType no admitido'),
  };
  final raw = Uint8List.fromList(
    ZLibDecoder().convert(idat.toBytes()),
  );

  final stride = width * channels;
  final rgba = Uint8List(width * height * 4);
  final line = Uint8List(stride);
  final prev = Uint8List(stride);
  var p = 0;

  for (var y = 0; y < height; y++) {
    final filter = raw[p++];
    line.setRange(0, stride, raw, p);
    p += stride;

    // Deshacer el filtro por líneas del PNG: cada una se guarda como
    // diferencia respecto a la de arriba y/o al píxel de la izquierda.
    for (var x = 0; x < stride; x++) {
      final a = x >= channels ? line[x - channels] : 0;
      final b = prev[x];
      final c = x >= channels ? prev[x - channels] : 0;
      line[x] = switch (filter) {
        1 => (line[x] + a) & 0xFF,
        2 => (line[x] + b) & 0xFF,
        3 => (line[x] + (a + b) ~/ 2) & 0xFF,
        4 => (line[x] + _paeth(a, b, c)) & 0xFF,
        _ => line[x],
      };
    }

    for (var x = 0; x < width; x++) {
      final s = x * channels, d = (y * width + x) * 4;
      rgba[d] = line[s];
      rgba[d + 1] = line[s + 1];
      rgba[d + 2] = line[s + 2];
      rgba[d + 3] = channels == 4 ? line[s + 3] : 255;
    }
    prev.setRange(0, stride, line);
  }

  return _Image(width, height, rgba);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

int _readU32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

void _write(String path, _Image img) {
  File(path).writeAsBytesSync(_encodePng(img));
}

Uint8List _encodePng(_Image img) {
  final n = img.width;
  // Cada línea va precedida por su byte de filtro; 0 = sin filtro, que para
  // una imagen que se comprime una vez y no se vuelve a tocar sobra.
  final raw = Uint8List(img.height * (n * 4 + 1));
  var o = 0;
  for (var y = 0; y < img.height; y++) {
    raw[o++] = 0;
    raw.setRange(o, o + n * 4, img.rgba, y * n * 4);
    o += n * 4;
  }

  final idat = Uint8List.fromList(
    ZLibEncoder(gzip: false, level: 9).convert(raw),
  );

  final ihdr = BytesBuilder()
    ..add(_u32(img.width))
    ..add(_u32(img.height))
    ..add([8, 6, 0, 0, 0]); // 8 bits por canal, RGBA, sin entrelazado

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // firma PNG
    ..._chunk('IHDR', ihdr.toBytes()),
    ..._chunk('IDAT', idat),
    ..._chunk('IEND', Uint8List(0)),
  ]);
}

List<int> _chunk(String type, Uint8List data) {
  final typeAndData = <int>[...type.codeUnits, ...data];
  return [..._u32(data.length), ...typeAndData, ..._u32(_crc32(typeAndData))];
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

final Uint32List _crcTable = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
