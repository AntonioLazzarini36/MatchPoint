import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/ui/widgets/availability_picker.dart';
import 'package:match_point/features/onboarding/models/availability.dart';

/// Monta la rejilla dentro de un scroll, que es como aparece de verdad en
/// el registro y en Ajustes — un arrastre ahí compite con el scroll de la
/// página, y esa es justo la parte que puede no funcionar.
Future<WeeklyAvailability> _pump(WidgetTester tester) async {
  var value = WeeklyAvailability.empty;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => AvailabilityPicker(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    ),
  );
  return value;
}

void main() {
  testWidgets('tocar una casilla la marca y volver a tocarla la quita', (
    tester,
  ) async {
    await _pump(tester);

    // Lunes por la mañana: primera columna de días, primera franja.
    final cell = find.byKey(const ValueKey('avail-0-0'));
    expect(cell, findsOneWidget);

    await tester.tap(cell);
    await tester.pump();
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(cell);
    await tester.pump();
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('arrastrar por una franja marca todas las casillas que toca', (
    tester,
  ) async {
    await _pump(tester);

    // De lunes a viernes por la tarde, de un gesto: el caso real es
    // "entre semana por la tarde", y hacerlo casilla a casilla es la
    // fricción que hace que nadie rellene esto.
    final lunes = tester.getCenter(find.byKey(const ValueKey('avail-0-1')));
    final viernes = tester.getCenter(find.byKey(const ValueKey('avail-4-1')));

    final gesture = await tester.startGesture(lunes);
    await tester.pump();
    // Varios pasos, como un dedo de verdad: un solo salto no pasa por las
    // casillas intermedias.
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset.lerp(lunes, viernes, i / 8)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(find.byIcon(Icons.check), findsNWidgets(5));
  });
}
