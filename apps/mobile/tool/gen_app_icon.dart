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
//  1. **Quita el marco.** El logo es el círculo y nada más: lo que había
//     alrededor era blanco opaco, que en el escritorio de un móvil se lee
//     como un cuadrado blanco con un círculo dentro. Ahora es transparente y
//     el círculo se dimensiona para llenar el icono, así que no se ve ningún
//     fondo por detrás.
//
//  2. **Recolorea las dos mitades.** El original venía en naranja `#F4511E` y
//     verde `#2E7D32`. Ese naranja es justo el que la app dejó atrás al pasar
//     a la paleta de pista, y el verde es el `primary` de la marca, que en la
//     app significa "acción/estado" y no "deporte". Se usan los colores que
//     la app **ya** usa por deporte (`lib/core/utils/sport_words.dart`):
//     tierra batida para tenis y azul de tartán para correr. Así el icono
//     habla el mismo idioma que las tarjetas de Discovery.
//
//  3. **Separa el dibujo del fondo** para poder darle a Android un icono
//     adaptativo de verdad: capa de atrás = el círculo con sus dos mitades,
//     capa de delante = raqueta y zapatilla. Es lo que hace que el lanzador
//     pueda moverlas por separado en vez de tratar el icono como una estampa.
//
//  4. **Ajusta el tamaño del círculo a cada destino.** En el icono plano el
//     círculo es el lienzo entero; en el adaptativo tiene que ser 72 de los
//     108 dp de la capa, que es la parte que Android enseña. Por eso hay dos
//     fracciones y no una.
//
// La geometría (centro, radio, ancho del separador, colores de cada mitad) se
// **mide** del original en vez de estar escrita a mano, para que volver a
// exportar el logo a otro tamaño no obligue a tocar números aquí.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sourcePath = 'tool/logo_source.png';

/// Colores por deporte, copiados de `lib/core/utils/sport_words.dart`.
const _tennis = [0xC6, 0x5F, 0x3B]; // tierra batida
const _running = [0x3B, 0x7B, 0xC6]; // azul pista de atletismo
const _white = [0xFF, 0xFF, 0xFF];

/// Qué parte del lienzo ocupa el círculo en el icono plano (iOS, web y
/// Android antiguo): todo. Fuera del círculo el PNG es transparente.
const _flatCircleFraction = 1.0;

/// Y en el icono adaptativo de Android, donde no puede ser la misma: la capa
/// mide 108 dp pero el sistema sólo enseña los 72 centrales. 72/108 hace que
/// el círculo llene exactamente lo que se ve, así que en un lanzador con
/// máscara redonda el logo va de borde a borde y no asoma nada por detrás.
const _adaptiveCircleFraction = 72 / 108;

/// La capa de delante del icono adaptativo no se dibuja sobre los 108 dp de
/// la capa, sino dentro del 68% central: es el `<inset android:inset="16%">`
/// que escribe `flutter_launcher_icons`. Sin compensarlo, el dibujo saldría
/// encogido respecto al círculo que tiene detrás.
const _foregroundInsetCompensation = 108 / (108 * 0.68);

void main() {
  final src = _decodePng(File(_sourcePath).readAsBytesSync());
  final geo = _measure(src);
  final art = _artworkMask(src, geo);

  Directory('assets/icon').createSync(recursive: true);

  // Una sola escala mueve círculo y dibujo a la vez, así que las proporciones
  // del logo original se mantienen intactas en las tres salidas.
  final flat = geo.size * _flatCircleFraction / (geo.radius * 2);
  final adaptive = geo.size * _adaptiveCircleFraction / (geo.radius * 2);

  // Icono plano: web, iOS y el icono "de siempre" de Android para móviles
  // anteriores a los adaptativos. iOS no admite canal alfa, así que ahí
  // `flutter_launcher_icons` rellena las esquinas (`remove_alpha_ios`).
  _write(
    'assets/icon/app_icon.png',
    _compose(geo, art, withCircle: true, withArtwork: true, scale: flat),
  );

  // Capa de atrás del icono adaptativo: el círculo, sin el dibujo.
  _write(
    'assets/icon/app_icon_background.png',
    _compose(geo, art, withCircle: true, withArtwork: false, scale: adaptive),
  );

  // Capa de delante: sólo raqueta y zapatilla, sobre transparente y
  // compensando el `inset`, para que caigan justo donde toca del círculo de
  // la capa de atrás.
  _write(
    'assets/icon/app_icon_foreground.png',
    _compose(
      geo,
      art,
      withCircle: false,
      withArtwork: true,
      scale: adaptive * _foregroundInsetCompensation,
    ),
  );

  stdout.writeln(
    'Escritos assets/icon/app_icon{,_background,_foreground}.png '
    'desde $_sourcePath '
    '(círculo r=${geo.radius.toStringAsFixed(0)}, '
    'separador ${(geo.dividerHalfWidth * 2).toStringAsFixed(0)} px)',
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
  Float32List art, {
  required bool withCircle,
  required bool withArtwork,
  required double scale,
}) {
  final n = g.size;
  final px = Uint8List(n * n * 4);
  // Todo se escala respecto al centro del lienzo, no al del círculo original
  // (que estaba un píxel descentrado): así el resultado queda centrado de
  // verdad, que es lo que importa cuando el sistema lo recorta.
  final centre = n / 2.0;
  final radius = g.radius * scale;
  final dividerHalf = g.dividerHalfWidth * scale;

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

      if (withCircle) {
        // El círculo sobre transparente, con un píxel de transición en el
        // borde para que no salga dentado. Es la misma cobertura que luego
        // recorta el separador, así que ninguno de los dos se sale del logo.
        final inside = (0.5 - (math.sqrt(dx * dx + dy * dy) - radius)).clamp(
          0.0,
          1.0,
        );
        paint(dx < 0 ? _tennis : _running, inside);
        paint(_white, (0.5 - (dx.abs() - dividerHalf)).clamp(0.0, 1.0) * inside);
      }

      if (withArtwork) {
        // Deshacer la escala para saber de qué punto del original viene este
        // píxel. Al ir todo referido al mismo centro, raqueta y zapatilla
        // caen siempre en su mitad, sea cual sea la escala.
        final sx = g.cx + dx / scale;
        final sy = g.cy + dy / scale;
        paint(_white, _sample(art, g.size, sx, sy));
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
