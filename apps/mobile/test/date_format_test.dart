import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/utils/date_format_es.dart';

/// Las piezas del bloque de fecha de una tarjeta de partido. Se prueban
/// porque el bloque es de ancho fijo (52 px): un mes de cuatro letras o un
/// día de la semana entero desbordarían la tarjeta sin que ningún test de
/// compilación se entere.
void main() {
  test('el bloque son día, mes de 3 letras en mayúsculas y día de semana', () {
    final d = dateBlockEs(DateTime(2026, 9, 12)); // sábado
    expect(d.day, '12');
    expect(d.month, 'SEP');
    expect(d.weekday, 'sáb');
  });

  test('ningún mes del año se pasa de tres letras', () {
    for (var m = 1; m <= 12; m++) {
      final d = dateBlockEs(DateTime(2026, m, 1));
      expect(d.month.length, 3, reason: 'mes $m');
      expect(d.weekday.length, 3, reason: 'mes $m');
    }
  });

  group('relativeDayEs', () {
    final now = DateTime.now();

    test('hoy y mañana se dicen con palabras', () {
      expect(relativeDayEs(now), 'Hoy');
      expect(relativeDayEs(now.add(const Duration(days: 1))), 'Mañana');
    });

    test('dentro de la semana, en días', () {
      expect(relativeDayEs(now.add(const Duration(days: 3))), 'En 3 días');
    });

    test('más allá de una semana no dice nada', () {
      // "En 34 días" no ayuda a decidir nada y la fecha de al lado ya lo
      // cuenta mejor.
      expect(relativeDayEs(now.add(const Duration(days: 34))), isNull);
    });

    test('lo ya pasado tampoco', () {
      expect(relativeDayEs(now.subtract(const Duration(days: 2))), isNull);
    });
  });

  test('la hora va con dos cifras siempre', () {
    expect(formatTimeEs(DateTime(2026, 9, 12, 9, 5)), '09:05');
    expect(formatTimeEs(DateTime(2026, 9, 12, 18, 30)), '18:30');
  });
}
