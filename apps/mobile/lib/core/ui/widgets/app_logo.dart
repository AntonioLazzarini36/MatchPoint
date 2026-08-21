import 'package:flutter/material.dart';

/// Logo de la app. Es **el mismo PNG que el icono del lanzador**
/// (`assets/icon/app_icon.png`, dibujado por `tool/gen_app_icon.dart`), no un
/// segundo dibujo parecido: así lo que alguien toca en el escritorio y lo que
/// ve al abrir la app son la misma marca, y un cambio de icono no deja el de
/// dentro desincronizado.
///
/// Sustituye al antiguo `AppLogoPlaceholder` (círculo + `Icons.sports_tennis`),
/// que existía sólo mientras no hubiera un logo de verdad.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // El icono se genera cuadrado y con fondo hasta el borde, porque cada
      // sistema lo recorta a su manera. Aquí lo recortamos nosotros: redondeo
      // proporcional al tamaño para que se vea igual a 64 y a 88.
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        // El PNG es de 1024 px y aquí se pinta a menos de 100: sin esto,
        // Flutter se guarda en memoria la imagen entera a resolución
        // completa.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
