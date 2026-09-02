import 'package:match_point/core/i18n/app_locale.dart';

/// Qué opina de tu nivel la gente que ha jugado contigo.
///
/// Tres respuestas y no más: el nivel que dices está bien, te quedas corto, o
/// te sobra. Grueso a propósito — con cuatro niveles y partidos contados con
/// los dedos, cualquier cosa más fina sería precisión inventada.
enum LevelVerdict { accurate, higher, lower }

extension LevelVerdictApi on LevelVerdict {
  static LevelVerdict? fromApi(Object? value) => switch (value?.toString()) {
    'ACCURATE' => LevelVerdict.accurate,
    'HIGHER' => LevelVerdict.higher,
    'LOWER' => LevelVerdict.lower,
    _ => null,
  };

  /// La frase que se enseña en la ficha, con el número delante.
  ///
  /// Se habla de personas y no de porcentajes ("3 de 5 creen…"): con estas
  /// cifras un porcentaje suena a estadística y es un puñado de partidos.
  ///
  /// Las seis frases van enteras en cada idioma en vez de montarse aquí
  /// pegando "3 personas" y el resto. En inglés el verbo concuerda con el
  /// número —"1 person confirms" frente a "3 people confirm"— así que un
  /// prefijo común no da una frase correcta.
  String label(int votes, {required bool mine}) => switch (this) {
    LevelVerdict.accurate => mine
        ? S.current.levelAccurateMine(votes)
        : S.current.levelAccurateTheirs(votes),
    LevelVerdict.higher => mine
        ? S.current.levelHigherMine(votes)
        : S.current.levelHigherTheirs(votes),
    LevelVerdict.lower => mine
        ? S.current.levelLowerMine(votes)
        : S.current.levelLowerTheirs(votes),
  };
}
