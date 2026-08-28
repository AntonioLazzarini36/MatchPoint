import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/ui/widgets/discovery/when_filter_sheet.dart';
import 'package:match_point/features/onboarding/models/availability.dart';

/// Los atajos ("Este finde", "Por las noches"...) se comportan como un OR de
/// conjuntos: marcar suma, desmarcar quita **sólo lo que no sostenga otro**.
///
/// El caso que motiva el test: con finde y noches marcados a la vez, quitar
/// noches no puede llevarse las noches del sábado y el domingo, porque las
/// sostiene "Este finde". Es justo lo que haría un `& ~preset` ingenuo.
void main() {
  Future<WeeklyAvailability?> openAndTap(
    WidgetTester tester,
    List<String> taps,
  ) async {
    WeeklyAvailability? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showWhenFilterSheet(
                  context,
                  current: WeeklyAvailability.empty,
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    for (final label in taps) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.textContaining('Ver'));
    await tester.pumpAndSettle();
    return result;
  }

  /// `bit = día * 3 + franja`; sábado y domingo son 5 y 6, noche es 2.
  bool has(WeeklyAvailability a, int day, int band) =>
      a.mask & (1 << (day * 3 + band)) != 0;

  testWidgets('marcar un atajo pone sus huecos', (tester) async {
    final r = await openAndTap(tester, ['Este finde']);
    expect(r, isNotNull);
    expect(has(r!, 5, 0), isTrue, reason: 'sábado mañana');
    expect(has(r, 6, 2), isTrue, reason: 'domingo noche');
    expect(has(r, 0, 0), isFalse, reason: 'el lunes no es finde');
  });

  testWidgets('volver a tocarlo lo quita', (tester) async {
    final r = await openAndTap(tester, ['Este finde', 'Este finde']);
    expect(r!.isEmpty, isTrue);
  });

  testWidgets(
    'quitar "noches" conserva las noches que sostiene "Este finde"',
    (tester) async {
      final r = await openAndTap(tester, [
        'Este finde',
        'Por las noches',
        'Por las noches',
      ]);
      expect(r, isNotNull);

      // Las noches del finde se quedan: las pone el otro atajo.
      expect(has(r!, 5, 2), isTrue, reason: 'sábado noche');
      expect(has(r, 6, 2), isTrue, reason: 'domingo noche');
      // Las de entre semana se van con el atajo que las trajo.
      expect(has(r, 0, 2), isFalse, reason: 'lunes noche');
      expect(has(r, 3, 2), isFalse, reason: 'jueves noche');
      // Y el resto del finde sigue intacto.
      expect(has(r, 5, 0), isTrue, reason: 'sábado mañana');
    },
  );

  testWidgets(
    'y al revés: quitar "Este finde" conserva lo que sostiene "noches"',
    (tester) async {
      final r = await openAndTap(tester, [
        'Este finde',
        'Por las noches',
        'Este finde',
      ]);
      expect(r, isNotNull);

      expect(has(r!, 5, 2), isTrue, reason: 'sábado noche la sostiene noches');
      expect(has(r, 0, 2), isTrue, reason: 'lunes noche');
      expect(has(r, 5, 0), isFalse, reason: 'sábado mañana era sólo del finde');
    },
  );
}
