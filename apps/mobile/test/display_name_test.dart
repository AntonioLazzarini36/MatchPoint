import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/i18n/app_locale.dart';
import 'package:match_point/core/utils/display_name.dart';
import 'package:match_point/features/discovery/models/level_verdict.dart';

/// Cómo se escribe el nombre de alguien, y las frases del veredicto de nivel.
///
/// Van juntas porque las dos salieron del mismo sitio: frases que la app monta
/// con el nombre dentro, donde un nombre en minúscula o una cadena sin traducir
/// se leen como un fallo del programa.
void main() {
  group('el nombre que se enseña', () {
    test('levanta la primera letra', () {
      expect(formatDisplayName('antonio'), 'Antonio');
      expect(formatDisplayName('marco'), 'Marco');
    });

    test('no toca lo que ya venía en mayúscula', () {
      // Quien firma así lo ha hecho a propósito; "corregirlo" sería
      // inventarse cómo se llama.
      expect(formatDisplayName('McEnroe'), 'McEnroe');
      expect(formatDisplayName('ANA'), 'ANA');
    });

    test('las partículas se quedan en minúscula', () {
      // Sin esto saldría "Juan De La Cruz", peor escrito que el original.
      expect(formatDisplayName('juan de la cruz'), 'Juan de la Cruz');
      expect(formatDisplayName('rafa van der berg'), 'Rafa van der Berg');
    });

    test('la primera palabra va en mayúscula aunque sea partícula', () {
      expect(formatDisplayName('de la fuente'), 'De la Fuente');
    });

    test('aguanta lo vacío y los espacios de más', () {
      expect(formatDisplayName(''), '');
      expect(formatDisplayName('   '), '');
      expect(formatDisplayName('  ana   maria '), 'Ana Maria');
    });
  });

  /// El veredicto de nivel estaba escrito en castellano dentro del modelo, así
  /// que con la app en inglés seguía diciendo "4 personas confirman tu nivel".
  /// Se prueban las seis frases en los dos idiomas porque son seis cadenas
  /// separadas y basta con olvidar una.
  group('lo que opina la gente de tu nivel', () {
    test('en castellano, con el singular bien puesto', () {
      LocaleController.locale.value = AppLocale.es;
      expect(
        LevelVerdict.accurate.label(4, mine: true),
        '4 personas confirman tu nivel',
      );
      // El singular concuerda: antes decía "1 persona confirman".
      expect(
        LevelVerdict.accurate.label(1, mine: true),
        '1 persona confirma tu nivel',
      );
      expect(
        LevelVerdict.accurate.label(4, mine: false),
        '4 personas confirman su nivel',
      );
    });

    test('en inglés el verbo concuerda con el número', () {
      LocaleController.locale.value = AppLocale.en;
      expect(
        LevelVerdict.accurate.label(1, mine: true),
        '1 person confirms your level',
      );
      expect(
        LevelVerdict.accurate.label(4, mine: true),
        '4 people confirm your level',
      );
    });

    test('ninguna de las seis se queda en castellano con la app en inglés', () {
      LocaleController.locale.value = AppLocale.en;
      for (final verdict in LevelVerdict.values) {
        for (final mine in [true, false]) {
          final text = verdict.label(3, mine: mine);
          final spanish = RegExp(
            r'\b(personas|persona|creen|cree|nivel|que|juegas|juega)\b',
            caseSensitive: false,
          );
          expect(
            spanish.hasMatch(text),
            isFalse,
            reason: '$verdict mine=$mine seguía en castellano: $text',
          );
        }
      }
    });
  });
}
