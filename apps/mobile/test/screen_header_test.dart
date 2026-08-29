import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/ui/widgets/screen_header.dart';

/// Las tres pantallas de la barra usan la misma cabecera, y la única
/// diferencia entre ellas es si llevan botones a la derecha o no.
///
/// Eso bastaba para que se vieran distintas: un `IconButton` mide 48 dp, así
/// que la cabecera con botón medía 48 y la de Partidos —la única sin
/// acciones— encogía hasta el alto del texto, quedando más arriba y
/// pareciendo más pequeña aun siendo el mismo estilo.
void main() {
  Future<Size> headerSize(WidgetTester tester, {List<Widget> actions = const []}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [ScreenHeader(title: 'Título', actions: actions)],
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(ScreenHeader));
  }

  testWidgets('mide lo mismo con botones y sin ellos', (tester) async {
    final conAcciones = await headerSize(
      tester,
      actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.tune))],
    );
    final sinAcciones = await headerSize(tester);

    expect(
      sinAcciones.height,
      conAcciones.height,
      reason:
          'una pantalla sin botones no puede tener la cabecera más baja: es '
          'lo que hacía que Partidos se viera distinta de las otras dos',
    );
  });

  testWidgets('el buscador ocupa el sitio del título sin cambiar el alto', (
    tester,
  ) async {
    final normal = await headerSize(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScreenHeader(
                title: 'Título',
                replacement: const TextField(),
                actions: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final buscando = tester.getSize(find.byType(ScreenHeader));

    expect(
      buscando.height,
      normal.height,
      reason: 'abrir el buscador de Compañeros no debe mover la pantalla',
    );
  });
}
