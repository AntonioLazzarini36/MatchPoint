import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Proporcion horizontal unica de la app. 16:9 es la de una foto de accion
/// deportiva (una pista, alguien corriendo) y la que ya usan las tarjetas
/// de Discovery, asi que recortar aqui evita que cada pantalla recorte a
/// su manera y que la misma foto se vea distinta en cada sitio.
const double kPhotoAspectRatio = 16 / 9;

/// Ancho maximo del resultado. El backend rechaza por encima de 5 MB y
/// esto sale PNG (sin perdida, mas pesado que JPEG), asi que conviene no
/// guardar mas resolucion de la que ninguna pantalla va a mostrar.
const int _maxWidth = 1280;

/// Recorta al centro para dejar la foto en 16:9.
///
/// Se hace con `dart:ui` en vez de con el paquete `image` a proposito: no
/// añade dependencia, funciona igual en movil y en web, y usa la GPU en
/// lugar de recorrer pixeles en Dart.
///
/// Recorta por el centro porque es donde suele estar el sujeto y porque
/// cualquier alternativa (detectar caras, dejar elegir el encuadre) es
/// bastante mas maquinaria; el usuario ve el resultado antes de subirlo,
/// que es lo que evita sorpresas.
Future<Uint8List> cropToLandscape(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final src = frame.image;

  try {
    final srcWidth = src.width.toDouble();
    final srcHeight = src.height.toDouble();

    // Region de origen: el rectangulo 16:9 mas grande que cabe, centrado.
    double cropWidth = srcWidth;
    double cropHeight = srcWidth / kPhotoAspectRatio;
    if (cropHeight > srcHeight) {
      cropHeight = srcHeight;
      cropWidth = srcHeight * kPhotoAspectRatio;
    }
    final srcRect = Rect.fromLTWH(
      (srcWidth - cropWidth) / 2,
      (srcHeight - cropHeight) / 2,
      cropWidth,
      cropHeight,
    );

    final targetWidth = cropWidth > _maxWidth ? _maxWidth : cropWidth.round();
    final targetHeight = (targetWidth / kPhotoAspectRatio).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      srcRect,
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();

    final cropped = await picture.toImage(targetWidth, targetHeight);
    try {
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        // Sin datos no hay nada que subir: mejor devolver el original
        // que dejar al usuario sin poder añadir foto.
        return bytes;
      }
      return data.buffer.asUint8List();
    } finally {
      cropped.dispose();
      picture.dispose();
    }
  } finally {
    src.dispose();
  }
}
