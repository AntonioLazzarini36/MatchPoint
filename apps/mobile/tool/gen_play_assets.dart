// Genera los dos gráficos **obligatorios** de la ficha de Google Play:
//
//   dart run tool/gen_play_assets.dart
//
//   play/icon_512.png          512x512, opaco   (icono de la ficha)
//   play/feature_graphic.png   1024x500, opaco  (imagen destacada)
//
// Por qué existe este fichero y no está metido en `gen_app_icon.dart`: aquél
// sólo sabe hacer imágenes **cuadradas** (`_compose` recorre n x n y `_resize`
// asume lados iguales), y la imagen destacada es 1024x500. Meterle rectángulos
// a un generador cuyo caso de uso es un icono habría obligado a tocar la
// geometría que ya está medida y probada ahí. Aquí se parte del resultado
// —`assets/icon/app_icon.png`, naranja liso con la raqueta blanca— en vez de
// del logo original, así que este fichero no repite nada de aquella medición:
// la raqueta se recupera del icono ya hecho con la misma proyección de color.
//
// **El texto se dibuja a trazo, no con una fuente.** No hay rasterizador de
// tipografías en Dart puro, pero es que además aquí es la decisión correcta:
// las letras se pintan con el mismo grosor y el mismo blanco que las líneas de
// una pista de tenis, que es lo que hay pintado de fondo. El nombre y la pista
// se dibujan con el mismo pincel. Un tipo de letra descargado sería un
// elemento ajeno pegado encima.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _iconPath = 'assets/icon/app_icon.png';
const _outDir = 'play';

/// Tierra batida, el mismo de `lib/core/utils/sport_words.dart`.
const _clay = [0xC6, 0x5F, 0x3B];
const _white = [0xFF, 0xFF, 0xFF];

/// Medidas que Google Play exige, no elegidas por nosotros.
const _iconSize = 512;
const _featureW = 1024;
const _featureH = 500;

void main() {
  final icon = _decodePng(File(_iconPath).readAsBytesSync());
  final racket = _Art.fromFlatIcon(icon);

  Directory(_outDir).createSync(recursive: true);

  _write('$_outDir/icon_512.png', _resize(icon, _iconSize, _iconSize));
  _write('$_outDir/feature_graphic.png', _featureGraphic(racket));

  stdout.writeln(
    'Escritos $_outDir/icon_512.png y $_outDir/feature_graphic.png '
    '(raqueta ${racket.span.toStringAsFixed(0)} px del icono de ${icon.width})',
  );
}

// --- La imagen destacada ---

/// 1024x500: pista de fondo, nombre a la izquierda, raqueta a la derecha.
///
/// Sin nada transparente y con margen por los cuatro lados: Play recorta esta
/// imagen de formas distintas según dónde la enseñe, así que lo que importa no
/// puede tocar el borde.
_Image _featureGraphic(_Art art) {
  final canvas = _Canvas(_featureW, _featureH)..fill(_clay);

  // Las líneas de la pista, muy tenues: dan profundidad sin competir con
  // nada. Es el fondo, no un elemento.
  _drawCourt(canvas);

  // La raqueta, a la derecha y girada. El giro la saca de la simetría de
  // catálogo y sugiere el gesto del golpe.
  // El giro ensancha la caja que ocupa: con 17 grados el alto efectivo es
  // `alto·cos + ancho·sen`, y con 384 el mango llegaba a tocar el borde de
  // abajo. 350 lo deja con margen por los cuatro lados, que es lo que pide
  // Play porque recorta esta imagen distinto en cada sitio donde la enseña.
  art.paintInto(
    canvas,
    centreX: 858,
    centreY: 245,
    height: 350,
    rotationDegrees: -17,
    alpha: 1,
  );

  // El nombre. Dos tamaños: la marca manda, el deporte acompaña.
  //
  // El cuerpo sale de una cuenta, no del ojo: diez letras suman 7,92 anchos de
  // caja más nueve huecos, así que a 70 px de altura la palabra mide 630 y
  // acaba en 704 — por delante del borde izquierdo de la raqueta girada. Con
  // 78 se solapaban la T final y la cabeza.
  const left = 74.0;
  _drawText(
    canvas,
    'MATCHPOINT',
    x: left,
    baselineTop: 178,
    capHeight: 70,
    stroke: 9,
    tracking: 0.12,
  );
  _drawText(
    canvas,
    'TENIS',
    x: left + 4,
    baselineTop: 280,
    capHeight: 34,
    stroke: 5,
    tracking: 0.62, // muy espaciado: se lee como un subtítulo, no como marca
  );

  return canvas.toImage();
}

/// Media pista en planta, sangrando por la izquierda.
///
/// Se dibuja con las proporciones reales (23,77 x 10,97 m; pasillos de dobles
/// de 1,37 m; cuadros de saque a 6,40 m de la red) en vez de con rectángulos
/// inventados: quien juega al tenis reconoce esa retícula de un vistazo, y una
/// falsa se nota.
void _drawCourt(_Canvas c) {
  const alpha = 0.13;
  const stroke = 2.6;

  // Metros a píxeles. La pista se pone tumbada y grande, saliéndose por
  // arriba y por abajo, para que se lea como textura y no como un diagrama.
  const mx = 46.0; // px por metro
  final originX = -170.0; // sangra por la izquierda
  final centreY = _featureH / 2;

  double px(double metres) => originX + metres * mx;
  double py(double metresFromCentre) => centreY + metresFromCentre * mx;

  const halfSingles = 4.115; // 8,23 / 2
  const halfDoubles = 5.485; // 10,97 / 2
  const baseline = 11.885; // 23,77 / 2
  const service = 6.40;

  // Líneas de fondo y de saque (verticales en pantalla, la pista va tumbada).
  for (final m in [0.0, service, baseline]) {
    c.line(
      px(m),
      py(-halfDoubles),
      px(m),
      py(halfDoubles),
      _white,
      stroke,
      alpha,
    );
  }
  // Pasillos y líneas laterales.
  for (final h in [-halfDoubles, -halfSingles, halfSingles, halfDoubles]) {
    c.line(px(0), py(h), px(baseline), py(h), _white, stroke, alpha);
  }
  // Línea central de saque.
  c.line(px(0), py(0), px(service), py(0), _white, stroke, alpha);
}

// --- Texto a trazo ---

/// Dibuja `text` en mayúsculas con el trazo de las líneas de la pista.
///
/// `capHeight` es la altura de una letra; `tracking` es el hueco entre letras
/// en fracción de esa altura.
void _drawText(
  _Canvas c,
  String text, {
  required double x,
  required double baselineTop,
  required double capHeight,
  required double stroke,
  required double tracking,
}) {
  var cursor = x;
  for (final ch in text.split('')) {
    if (ch == ' ') {
      cursor += capHeight * 0.4;
      continue;
    }
    final glyph = _glyphs[ch];
    if (glyph == null) {
      throw StateError('No hay trazo para "$ch" — añádelo en _glyphs');
    }
    for (final stroke_ in glyph.strokes) {
      for (var i = 0; i + 1 < stroke_.length; i++) {
        c.line(
          cursor + stroke_[i][0] * glyph.width * capHeight,
          baselineTop + stroke_[i][1] * capHeight,
          cursor + stroke_[i + 1][0] * glyph.width * capHeight,
          baselineTop + stroke_[i + 1][1] * capHeight,
          _white,
          stroke,
          1,
        );
      }
    }
    cursor += glyph.width * capHeight + tracking * capHeight;
  }
}

/// Una letra: trazos en una caja de 0..1 (x) por 0..1 (y, hacia abajo), más su
/// anchura relativa a la altura de caja.
class _Glyph {
  const _Glyph(this.width, this.strokes);
  final double width;
  final List<List<List<double>>> strokes;
}

/// Genera los puntos de un arco de elipse, para las letras redondas.
List<List<double>> _arc(
  double cx,
  double cy,
  double rx,
  double ry,
  double fromDeg,
  double toDeg,
) {
  final pts = <List<double>>[];
  const steps = 28;
  for (var i = 0; i <= steps; i++) {
    final t = fromDeg + (toDeg - fromDeg) * i / steps;
    final r = t * math.pi / 180;
    // y hacia abajo, de ahí el signo del seno.
    pts.add([cx + rx * math.cos(r), cy - ry * math.sin(r)]);
  }
  return pts;
}

final Map<String, _Glyph> _glyphs = {
  'M': const _Glyph(0.88, [
    [
      [0, 1],
      [0, 0],
      [0.5, 0.66],
      [1, 0],
      [1, 1],
    ],
  ]),
  'A': const _Glyph(0.76, [
    [
      [0, 1],
      [0.5, 0],
      [1, 1],
    ],
    [
      [0.19, 0.63],
      [0.81, 0.63],
    ],
  ]),
  'T': const _Glyph(0.70, [
    [
      [0, 0],
      [1, 0],
    ],
    [
      [0.5, 0],
      [0.5, 1],
    ],
  ]),
  'C': _Glyph(0.76, [_arc(0.5, 0.5, 0.5, 0.5, 52, 308)]),
  'H': const _Glyph(0.74, [
    [
      [0, 0],
      [0, 1],
    ],
    [
      [1, 0],
      [1, 1],
    ],
    [
      [0, 0.5],
      [1, 0.5],
    ],
  ]),
  'P': _Glyph(0.68, [
    [
      [0, 1],
      [0, 0],
    ],
    [
      [0, 0],
      [0.42, 0],
      ..._arc(0.42, 0.28, 0.58, 0.28, 90, -90),
      [0.42, 0.56],
      [0, 0.56],
    ],
  ]),
  'O': _Glyph(0.80, [_arc(0.5, 0.5, 0.5, 0.5, 0, 360)]),
  'I': const _Glyph(0.16, [
    [
      [0.5, 0],
      [0.5, 1],
    ],
  ]),
  'N': const _Glyph(0.74, [
    [
      [0, 1],
      [0, 0],
      [1, 1],
      [1, 0],
    ],
  ]),
  'E': const _Glyph(0.64, [
    [
      [1, 0],
      [0, 0],
      [0, 1],
      [1, 1],
    ],
    [
      [0, 0.5],
      [0.72, 0.5],
    ],
  ]),
  'S': const _Glyph(0.70, [
    [
      [0.97, 0.14],
      [0.78, 0.01],
      [0.28, 0.01],
      [0.03, 0.16],
      [0.03, 0.36],
      [0.28, 0.5],
      [0.72, 0.5],
      [0.97, 0.64],
      [0.97, 0.86],
      [0.72, 0.99],
      [0.24, 0.99],
      [0.03, 0.86],
    ],
  ]),
};

// --- La raqueta, recuperada del icono ya generado ---

class _Art {
  _Art(this.mask, this.n, this.cx, this.cy, this.span);
  final Float32List mask;
  final int n;
  final double cx, cy, span;

  /// Saca la raqueta de `app_icon.png`, que es naranja liso con la raqueta
  /// blanca encima: cada píxel es `naranja + t·(blanco − naranja)`, así que
  /// proyectar sobre esa recta devuelve `t` — la cobertura del dibujo — con el
  /// antialiasing del original incluido. Mismo truco que `_artworkMask` en
  /// `gen_app_icon.dart`, y por el mismo motivo: nada de umbrales, que dejan
  /// el borde dentado.
  factory _Art.fromFlatIcon(_Image img) {
    final n = img.width;
    final mask = Float32List(n * n);
    var minX = n, maxX = -1, minY = n, maxY = -1;

    var len = 0.0;
    for (var c = 0; c < 3; c++) {
      final axis = 255.0 - _clay[c];
      len += axis * axis;
    }

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final p = img.at(x, y);
        var dot = 0.0;
        for (var c = 0; c < 3; c++) {
          dot += (p[c] - _clay[c]) * (255.0 - _clay[c]);
        }
        final t = (dot / len).clamp(0.0, 1.0);
        mask[y * n + x] = t;
        if (t < 0.35) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < 0) throw StateError('No se encontró la raqueta en $_iconPath');

    return _Art(
      mask,
      n,
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      math.max(maxX - minX, maxY - minY).toDouble(),
    );
  }

  /// La pinta sobre el lienzo con el alto pedido, girada sobre su centro.
  void paintInto(
    _Canvas c, {
    required double centreX,
    required double centreY,
    required double height,
    required double rotationDegrees,
    required double alpha,
  }) {
    final scale = height / span;
    final r = -rotationDegrees * math.pi / 180;
    final cosR = math.cos(r), sinR = math.sin(r);

    // Sólo se recorre la caja que puede tocar, no el lienzo entero.
    final reach = (span * scale).ceil();
    final x0 = math.max(0, (centreX - reach).floor());
    final x1 = math.min(c.width, (centreX + reach).ceil());
    final y0 = math.max(0, (centreY - reach).floor());
    final y1 = math.min(c.height, (centreY + reach).ceil());

    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final dx = x + 0.5 - centreX;
        final dy = y + 0.5 - centreY;
        // Girar el punto al revés para saber de dónde viene del original.
        final rx = dx * cosR - dy * sinR;
        final ry = dx * sinR + dy * cosR;
        final v = _sample(mask, n, cx + rx / scale, cy + ry / scale);
        if (v > 0) c.blend(x, y, _white, v * alpha);
      }
    }
  }
}

// --- Lienzo ---

class _Canvas {
  _Canvas(this.width, this.height) : px = Float32List(width * height * 3);
  final int width, height;
  final Float32List px;

  void fill(List<int> color) {
    for (var i = 0; i < width * height; i++) {
      px[i * 3] = color[0].toDouble();
      px[i * 3 + 1] = color[1].toDouble();
      px[i * 3 + 2] = color[2].toDouble();
    }
  }

  void blend(int x, int y, List<int> color, double a) {
    if (a <= 0 || x < 0 || y < 0 || x >= width || y >= height) return;
    final i = (y * width + x) * 3;
    final inv = 1 - a;
    px[i] = color[0] * a + px[i] * inv;
    px[i + 1] = color[1] * a + px[i + 1] * inv;
    px[i + 2] = color[2] * a + px[i + 2] * inv;
  }

  /// Segmento con extremos redondeados y antialiasing, por distancia: la
  /// cobertura de un píxel sale de lo lejos que está su centro del eje del
  /// trazo. Es lo que hace que las letras y las líneas de la pista compartan
  /// exactamente el mismo pincel.
  void line(
    double ax,
    double ay,
    double bx,
    double by,
    List<int> color,
    double strokeWidth,
    double alpha,
  ) {
    final half = strokeWidth / 2;
    final minX = math.max(0, (math.min(ax, bx) - half - 1).floor());
    final maxX = math.min(width - 1, (math.max(ax, bx) + half + 1).ceil());
    final minY = math.max(0, (math.min(ay, by) - half - 1).floor());
    final maxY = math.min(height - 1, (math.max(ay, by) + half + 1).ceil());

    final vx = bx - ax, vy = by - ay;
    final lenSq = vx * vx + vy * vy;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final pxc = x + 0.5, pyc = y + 0.5;
        var t = lenSq == 0 ? 0.0 : ((pxc - ax) * vx + (pyc - ay) * vy) / lenSq;
        t = t.clamp(0.0, 1.0);
        final ddx = pxc - (ax + t * vx), ddy = pyc - (ay + t * vy);
        final dist = math.sqrt(ddx * ddx + ddy * ddy);
        // Un píxel de transición: fuera del trazo 0, dentro 1.
        final cov = (half + 0.5 - dist).clamp(0.0, 1.0);
        if (cov > 0) blend(x, y, color, cov * alpha);
      }
    }
  }

  _Image toImage() {
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      rgba[i * 4] = px[i * 3].round().clamp(0, 255);
      rgba[i * 4 + 1] = px[i * 3 + 1].round().clamp(0, 255);
      rgba[i * 4 + 2] = px[i * 3 + 2].round().clamp(0, 255);
      rgba[i * 4 + 3] = 255; // Play no admite transparencia en estos dos
    }
    return _Image(width, height, rgba);
  }
}

/// Reduce promediando cada bloque de origen, conservando el color (a
/// diferencia del `_resize` de `gen_app_icon.dart`, que sólo guarda el alfa
/// porque aquél alimenta un icono que Android recolorea).
_Image _resize(_Image src, int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final sx0 = x * src.width ~/ w;
      final sx1 = ((x + 1) * src.width ~/ w).clamp(sx0 + 1, src.width);
      final sy0 = y * src.height ~/ h;
      final sy1 = ((y + 1) * src.height ~/ h).clamp(sy0 + 1, src.height);

      var r = 0.0, g = 0.0, b = 0.0, count = 0;
      for (var sy = sy0; sy < sy1; sy++) {
        for (var sx = sx0; sx < sx1; sx++) {
          final p = src.at(sx, sy);
          r += p[0];
          g += p[1];
          b += p[2];
          count++;
        }
      }
      final i = (y * w + x) * 4;
      out[i] = (r / count).round().clamp(0, 255);
      out[i + 1] = (g / count).round().clamp(0, 255);
      out[i + 2] = (b / count).round().clamp(0, 255);
      out[i + 3] = 255;
    }
  }
  return _Image(w, h, out);
}

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

// --- PNG (mismo códec que gen_app_icon.dart) ---

class _Image {
  _Image(this.width, this.height, this.rgba);
  final int width, height;
  final Uint8List rgba;

  List<int> at(int x, int y) {
    final o = (y * width + x) * 4;
    return [rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]];
  }
}

_Image _decodePng(Uint8List bytes) {
  var width = 0, height = 0, colorType = 0;
  final idat = BytesBuilder();

  var i = 8;
  while (i < bytes.length) {
    final len = _readU32(bytes, i);
    final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
    final data = bytes.sublist(i + 8, i + 8 + len);
    if (type == 'IHDR') {
      width = _readU32(data, 0);
      height = _readU32(data, 4);
      if (data[8] != 8) throw StateError('Sólo 8 bits por canal');
      colorType = data[9];
      if (data[12] != 0) throw StateError('PNG entrelazado no admitido');
    } else if (type == 'IDAT') {
      idat.add(data);
    }
    i += 12 + len;
  }

  final channels = switch (colorType) {
    2 => 3,
    6 => 4,
    _ => throw StateError('Tipo de color $colorType no admitido'),
  };
  final raw = Uint8List.fromList(ZLibDecoder().convert(idat.toBytes()));

  final stride = width * channels;
  final rgba = Uint8List(width * height * 4);
  final line = Uint8List(stride);
  final prev = Uint8List(stride);
  var p = 0;

  for (var y = 0; y < height; y++) {
    final filter = raw[p++];
    line.setRange(0, stride, raw, p);
    p += stride;

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
  final w = img.width;
  final raw = Uint8List(img.height * (w * 4 + 1));
  var o = 0;
  for (var y = 0; y < img.height; y++) {
    raw[o++] = 0;
    raw.setRange(o, o + w * 4, img.rgba, y * w * 4);
    o += w * 4;
  }

  final idat = Uint8List.fromList(
    ZLibEncoder(gzip: false, level: 9).convert(raw),
  );

  final ihdr = BytesBuilder()
    ..add(_u32(img.width))
    ..add(_u32(img.height))
    ..add([8, 6, 0, 0, 0]);

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
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
