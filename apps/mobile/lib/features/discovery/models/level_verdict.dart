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
  String label(int votes, {required bool mine}) {
    final gente = votes == 1 ? '1 persona' : '$votes personas';
    return switch (this) {
      LevelVerdict.accurate => mine
          ? '$gente confirman tu nivel'
          : '$gente confirman su nivel',
      LevelVerdict.higher => mine
          ? '$gente creen que juegas mejor de lo que pones'
          : '$gente creen que juega mejor de lo que pone',
      LevelVerdict.lower => mine
          ? '$gente creen que te sobra nivel en tu perfil'
          : '$gente creen que le sobra nivel en su perfil',
    };
  }
}
