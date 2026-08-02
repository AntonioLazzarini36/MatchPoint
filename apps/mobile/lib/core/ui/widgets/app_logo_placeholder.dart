import 'package:flutter/material.dart';

/// Espacio reservado para el logo real de la app — de momento un
/// placeholder dibujado (círculo + ícono), fácil de reemplazar más
/// adelante por `Image.asset('assets/images/logo.png')` cuando exista
/// un logo de verdad. Pedido del usuario (2026-08-03): welcome/login/
/// registro se sentían "muy fríos" sin ningún elemento de marca.
class AppLogoPlaceholder extends StatelessWidget {
  final double size;
  final Color? background;
  final Color? foreground;

  const AppLogoPlaceholder({
    super.key,
    this.size = 72,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 2),
      ),
      child: Icon(Icons.sports_tennis, color: fg, size: size * 0.5),
    );
  }
}
