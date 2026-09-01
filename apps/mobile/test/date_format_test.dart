import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/i18n/app_locale.dart';
import 'package:match_point/core/utils/date_format.dart';

/// Las fechas son lo que más fácilmente se queda sin traducir: los nombres de
/// los meses vivían escritos a mano en castellano, así que la app entera se
/// podía cambiar de idioma menos las fechas. Por eso se prueban **en los dos**.
///
/// Y el bloque de fecha de una tarjeta de partido es de ancho fijo (52 px):
/// un mes de cuatro letras o un día de la semana entero desbordarían sin que
/// ninguna compilación se entere.
void main() {
  group('en castellano', () {
    setUp(() => LocaleController.locale.value = AppLocale.es);

    test('el bloque son día, mes de 3 letras y día de semana', () {
      final d = dateBlock(DateTime(2026, 9, 12)); // sábado
      expect(d.day, '12');
      expect(d.month, 'SEP');
      expect(d.weekday, 'sáb');
    });

    test('hoy, mañana y dentro de unos días', () {
      final now = DateTime.now();
      expect(relativeDay(now), 'Hoy');
      expect(relativeDay(now.add(const Duration(days: 1))), 'Mañana');
      expect(relativeDay(now.add(const Duration(days: 3))), 'En 3 días');
    });

    test('la fecha larga lleva el "de" del castellano', () {
      // 12 de septiembre de 2026 a las 18:30
      final s = formatProposalDateTime(DateTime(2026, 9, 12, 18, 30));
      expect(s, contains('de septiembre'));
      expect(s, contains('a las 18:30'));
    });
  });

  group('in English', () {
    setUp(() => LocaleController.locale.value = AppLocale.en);

    test('the date block is translated too', () {
      final d = dateBlock(DateTime(2026, 9, 12));
      expect(d.month, 'SEP');
      expect(d.weekday, 'Sat');
    });

    test('today, tomorrow and a few days out', () {
      final now = DateTime.now();
      expect(relativeDay(now), 'Today');
      expect(relativeDay(now.add(const Duration(days: 1))), 'Tomorrow');
      expect(relativeDay(now.add(const Duration(days: 3))), 'In 3 days');
    });

    test('the long date drops the Spanish "de"', () {
      final s = formatProposalDateTime(DateTime(2026, 9, 12, 18, 30));
      expect(s, contains('September'));
      expect(s, isNot(contains(' de ')));
      expect(s, contains('at 18:30'));
    });
  });

  group('igual en los dos idiomas', () {
    for (final locale in AppLocale.values) {
      test('ningún mes ni día se pasa de tres letras (${locale.code})', () {
        LocaleController.locale.value = locale;
        for (var m = 1; m <= 12; m++) {
          final d = dateBlock(DateTime(2026, m, 1));
          expect(d.month.length, 3, reason: 'mes $m');
          expect(d.weekday.length, 3, reason: 'mes $m');
        }
      });
    }

    test('la hora va con dos cifras siempre', () {
      expect(formatTime(DateTime(2026, 9, 12, 9, 5)), '09:05');
      expect(formatTime(DateTime(2026, 9, 12, 18, 30)), '18:30');
    });
  });
}
