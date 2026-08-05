import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Foto remota con hueco de reserva si no se puede cargar.
///
/// `Image.network` a pelo, cuando la URL da 404, deja un recuadro vacío sin
/// explicación — y eso pasa de verdad: si el servidor pierde los ficheros
/// (un contenedor sin volumen persistente se los lleva en cada
/// despliegue), la base de datos sigue teniendo las URLs pero detrás no hay
/// nada. Mejor un icono honesto que un agujero gris.
class NetworkPhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;

  /// Tamaño del icono del hueco. Más pequeño en rejillas, más grande en una
  /// cabecera de perfil.
  final double iconSize;

  const NetworkPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, _, _) => ColoredBox(
        color: context.colors.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: iconSize,
            color: context.colors.outline,
          ),
        ),
      ),
    );
  }
}
