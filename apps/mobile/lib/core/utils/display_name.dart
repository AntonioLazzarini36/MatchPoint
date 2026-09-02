/// Cómo se escribe el nombre de alguien en la interfaz.
///
/// Existe porque el nombre lo teclea cada uno al registrarse, y mucha gente
/// escribe en minúscula. Eso, suelto en una lista, apenas se nota; dentro de
/// una frase montada por la app —"Partido con antonio", "Sólo puede marco"—
/// se lee como un fallo del programa, no como una decisión de quien lo
/// escribió.
///
/// Se aplica al **leer del JSON** y no en cada pantalla: hay exactamente dos
/// sitios donde la app convierte un perfil del servidor en un objeto
/// (`Profile.fromJson` y `DiscoverProfile`), así que arreglarlo ahí lo arregla
/// en el chat, en la ficha, en Partidos y en Descubrir a la vez. Repartido por
/// las pantallas, cualquiera nueva se olvidaría.
///
/// **No toca lo que ya está escrito en mayúscula.** Sólo levanta la primera
/// letra si está en minúscula: quien firme "McEnroe" o "ANA" se queda como
/// quiso.
library;

/// Partículas que en castellano van en minúscula dentro de un nombre.
///
/// Sin esta lista, "juan de la cruz" se convertiría en "Juan De La Cruz", que
/// está peor escrito que el original. Se incluyen también las de otros
/// idiomas que aparecen en apellidos de por aquí.
const _particles = {
  'de', 'del', 'la', 'las', 'los', 'y', 'e',
  'van', 'von', 'da', 'das', 'di', 'du', 'der', 'den',
};

/// "antonio" → "Antonio"; "juan de la cruz" → "Juan de la Cruz".
String formatDisplayName(String raw) {
  final clean = raw.trim();
  if (clean.isEmpty) return clean;

  final words = clean.split(RegExp(r'\s+'));
  return words.indexed
      .map((entry) {
        final (index, word) = entry;
        // La primera palabra siempre va en mayúscula, aunque sea una
        // partícula: nadie se llama "de la cruz" empezando en minúscula.
        if (index > 0 && _particles.contains(word.toLowerCase())) {
          return word.toLowerCase();
        }
        return _upperFirst(word);
      })
      .join(' ');
}

/// Levanta la primera letra y deja el resto intacto.
///
/// Intacto a propósito: pasar el resto a minúscula rompería "McEnroe" y
/// convertiría en "Ana" a quien escribió "ANA" queriendo.
String _upperFirst(String word) {
  if (word.isEmpty) return word;
  return word[0].toUpperCase() + word.substring(1);
}
