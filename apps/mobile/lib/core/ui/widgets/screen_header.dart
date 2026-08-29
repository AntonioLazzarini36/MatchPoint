import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// La cabecera de las pantallas principales.
///
/// Antes cada una hacía la suya: Descubrir se pintaba un título grande a mano
/// y Compañeros y Partidos usaban un `AppBar` de Material con el título
/// pequeño y centrado. Puestas una al lado de otra en la barra de navegación
/// se notaba que eran de dos apps distintas — y la que mejor quedaba era la
/// que no usaba `AppBar`.
///
/// Así que ésta es aquélla, extraída para que las tres compartan formato y no
/// vuelvan a separarse: titular grande y en negrita, alineado a la izquierda,
/// con las acciones a la derecha.
class ScreenHeader extends StatelessWidget {
  /// Alto mínimo del bloque, **haya botones o no**.
  ///
  /// Es lo que hace que las tres pantallas se vean iguales, y no es un
  /// capricho: un `IconButton` de Material mide 48 dp, así que una cabecera
  /// con botón mide 48 y una sin botón encoge hasta el alto del texto. Con
  /// esa diferencia, Partidos —la única sin acciones— se veía más arriba que
  /// las otras dos y el titular parecía más pequeño por contraste, aun siendo
  /// exactamente el mismo estilo. Se fija aquí para que añadir o quitar un
  /// botón no vuelva a mover la pantalla.
  static const _minContentHeight = 48.0;

  final String title;

  /// Botones de la derecha (buscar, filtros...). Van con el mismo tamaño de
  /// toque que un `IconButton` normal.
  final List<Widget> actions;

  /// Sustituye al título cuando hay algo que escribir en su lugar — el
  /// buscador de Compañeros, sin salirse del mismo bloque.
  final Widget? replacement;

  const ScreenHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minContentHeight),
        child: Row(
          children: [
            Expanded(
              child:
                  replacement ??
                  Text(
                    title,
                    style: context.textStyles.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
