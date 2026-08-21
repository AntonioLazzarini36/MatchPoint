import 'package:flutter/material.dart';

/// Fondo de las pantallas de entrada (bienvenida).
///
/// Antes era una foto a pantalla completa (`assets/images/welcome.jpg`, 3,3 MB)
/// con un degradado negro encima para poder leer el texto. Se quitó: la foto
/// no decía nada del producto, pesaba más que todo el resto de la app junta y
/// obligaba a oscurecerla tanto que casi no se veía. Ahora es un degradado
/// sólido de la propia paleta, que además deja resaltar el verde de los
/// botones y los colores del logo.
class BackgroundScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const BackgroundScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0B1220)],
          ),
        ),
        child: SafeArea(
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
