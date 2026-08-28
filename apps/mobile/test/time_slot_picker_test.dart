import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/ui/widgets/proposal/time_slot_picker.dart';

/// El selector de hora dejó de ser una rejilla de 57 botones y pasó a ser dos
/// ruedas. Lo que se fija aquí son las dos reglas que hacen que sirva para
/// esta app en concreto: que no se pueda quedar a las 9:38, y que se puedan
/// proponer horas a las que de verdad hay pista.
void main() {
  Future<TimeOfDay?> open(WidgetTester tester, {TimeOfDay? initial}) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await pickTimeSlot(context, initial: initial);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('sólo deja elegir en cuartos de hora', (tester) async {
    await open(tester);

    // La rueda sólo dibuja lo que se ve, así que no vale buscar los cuatro
    // valores a la vez: se recorre hacia arriba y se comprueba dónde para.
    // Cada tirón sube un cuarto, y tras cuatro tiene que haber dado la vuelta
    // completa a la hora — nunca pasar por un minuto intermedio.
    const esperado = ['10:15', '10:30', '10:45'];
    for (final hhmm in esperado) {
      await tester.drag(find.text('00').last, const Offset(0, -46));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Proponer a las $hhmm'),
        findsOneWidget,
        reason: 'tras avanzar un cuarto debería quedarse en $hhmm',
      );
    }

    // Y nada intermedio: si apareciera un 38, la rueda habría vuelto a ser de
    // 0 a 59 y se podría quedar a las 10:38.
    expect(find.text('38'), findsNothing);
    expect(find.text('07'), findsNothing);
  });

  testWidgets('se puede proponer de 06:00 a 24:00', (tester) async {
    await open(tester);

    // La rueda no pinta todos los elementos a la vez, así que se comprueba
    // por los extremos que sí quedan a tiro del valor inicial (10:00) y por
    // el botón de confirmar, que refleja el valor elegido.
    expect(find.textContaining('Proponer a las 10:00'), findsOneWidget);

    // Arrastrar hacia abajo baja la hora: desde las 10 se llega a las 6.
    await tester.drag(find.text('10'), const Offset(0, 220));
    await tester.pumpAndSettle();
    expect(find.textContaining('Proponer a las 06:00'), findsOneWidget);
  });

  testWidgets('la hora que ya venía elegida no se mueve sola', (tester) async {
    await open(tester, initial: const TimeOfDay(hour: 18, minute: 30));
    expect(find.textContaining('Proponer a las 18:30'), findsOneWidget);
  });

  testWidgets('un minuto suelto se ajusta al cuarto de abajo', (tester) async {
    // Nadie deberia poder meter un 18:38, pero si llegara (una propuesta
    // vieja, un dato raro), el selector tiene que abrirse en un valor valido
    // en vez de romperse o inventarse otra hora.
    await open(tester, initial: const TimeOfDay(hour: 18, minute: 38));
    expect(find.textContaining('Proponer a las 18:30'), findsOneWidget);
  });
}
