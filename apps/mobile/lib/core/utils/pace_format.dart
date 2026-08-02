/// Ritmo de carrera, guardado en el backend como minutos decimales por km
/// (`Profile.avgPaceMinPerKm`, p.ej. `4.5`) pero mostrado/editado como
/// "min:seg" (`4:30`), que es como la gente que corre realmente piensa su
/// ritmo — nadie dice "cuatro coma cinco minutos por km".
library;

/// Acepta tanto "4:30" (min:seg) como "4.5" (decimal) — quien escribe no
/// tiene por qué saber que puede usar cualquiera de los dos, pero ninguno
/// de los dos formatos debería fallar sorpresivamente. Devuelve `null`
/// mientras el texto todavía no es un ritmo válido (p.ej. a medio
/// escribir "4:"), sin lanzar excepción.
double? parsePaceMinPerKm(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.contains(':')) {
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    if (seconds < 0 || seconds > 59) return null;
    return minutes + seconds / 60.0;
  }

  return double.tryParse(trimmed);
}

/// Inverso de `parsePaceMinPerKm`, para precargar el campo con el valor
/// ya guardado — siempre en formato "min:seg", nunca decimal, para que
/// lo que se ve sea consistente con lo que se puede escribir.
String formatPaceMinPerKm(double? minPerKm) {
  if (minPerKm == null) return '';
  final totalSeconds = (minPerKm * 60).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
