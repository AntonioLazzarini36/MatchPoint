import 'package:flutter/material.dart';

/// Logo de la app. Sale del **mismo dibujo** que el icono del lanzador y del
/// mismo generador (`tool/gen_app_icon.dart`), así que no puede
/// desincronizarse, pero es un archivo distinto a propósito: aquí va
/// recortado en círculo (`app_logo.png`), mientras que el del lanzador llega
/// hasta el borde porque el sistema lo recorta con su propia forma y rellena
/// de negro lo que sobre.
///
/// Sustituye al antiguo `AppLogoPlaceholder` (círculo + `Icons.sports_tennis`),
/// que existía sólo mientras no hubiera un logo de verdad.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    // Sin recortar: el PNG ya es el círculo y sus esquinas son transparentes.
    return Image.asset(
      'assets/icon/app_logo.png',
      width: size,
      height: size,
      // El PNG es de 1024 px y aquí se pinta a menos de 100: sin esto,
      // Flutter se guarda en memoria la imagen entera a resolución completa.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      filterQuality: FilterQuality.medium,
    );
  }
}
