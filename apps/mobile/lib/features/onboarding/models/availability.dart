/// El horario semanal habitual de alguien (`Profile.availability`).
///
/// **Es una referencia, no una verdad.** Dice lo que esa persona *suele*
/// tener libre, no lo que puede esta semana. Por eso no filtra ni ordena
/// nada: se enseña a quien va a proponer una quedada, para que no elija un
/// hueco en el que la otra persona no puede nunca — y así no gastar tres
/// mensajes en descubrirlo.
///
/// Se guarda como un mapa de bits de 21 posiciones, `bit = día * 3 + franja`,
/// que es como llega y sale del backend. Un entero en vez de una lista de
/// nombres porque lo único que se hace con esto es pintarlo.
class WeeklyAvailability {
  /// Lunes primero, como una semana española.
  static const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const bands = ['Mañana', 'Tarde', 'Noche'];

  final int mask;
  const WeeklyAvailability(this.mask);

  static const empty = WeeklyAvailability(0);

  bool get isEmpty => mask == 0;

  static int bit(int day, int band) => 1 << (day * 3 + band);

  bool has(int day, int band) => mask & bit(day, band) != 0;

  WeeklyAvailability toggled(int day, int band) =>
      WeeklyAvailability(mask ^ bit(day, band));

  /// Cuántos huecos hay marcados. Sirve para decidir si merece la pena
  /// enseñar el detalle o basta con decir "casi siempre".
  int get count {
    var n = 0;
    for (var i = 0; i < 21; i++) {
      if (mask & (1 << i) != 0) n++;
    }
    return n;
  }

  /// Resumen corto, para una fila o una cabecera.
  ///
  /// No intenta describir el horario entero: con más de unos pocos huecos
  /// cualquier frase se vuelve ilegible, y para eso está la rejilla.
  String get summary {
    if (isEmpty) return 'Sin definir';
    if (count >= 15) return 'Casi siempre disponible';

    final byBand = <int, List<int>>{};
    for (var d = 0; d < 7; d++) {
      for (var b = 0; b < 3; b++) {
        if (has(d, b)) byBand.putIfAbsent(b, () => []).add(d);
      }
    }

    final parts = <String>[];
    byBand.forEach((band, days) {
      final names = days.map((d) => WeeklyAvailability.days[d]).join('');
      parts.add('${bands[band].toLowerCase()} $names');
    });
    final text = parts.join(' · ');
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Los huecos de un día concreto, en texto. Lo que se enseña al proponer.
  String labelForDay(int weekday) {
    // `DateTime.weekday` va de 1 (lunes) a 7 (domingo).
    final day = weekday - 1;
    final free = [
      for (var b = 0; b < 3; b++)
        if (has(day, b)) bands[b].toLowerCase(),
    ];
    if (free.isEmpty) return 'No suele tener libre';
    return 'Suele tener libre: ${free.join(', ')}';
  }

  bool hasAnyOn(int weekday) {
    final day = weekday - 1;
    return has(day, 0) || has(day, 1) || has(day, 2);
  }

  /// Las franjas libres de un día, como índices. Lo usa el selector de hora
  /// para atenuar las horas en las que esa persona no suele poder.
  Set<int> bandsOn(int weekday) {
    final day = weekday - 1;
    return {
      for (var b = 0; b < 3; b++)
        if (has(day, b)) b,
    };
  }

  /// A qué franja pertenece una hora del reloj.
  ///
  /// El corte vive aquí y en ningún otro sitio: la rejilla dice "tarde" y el
  /// selector de horas tiene que estar de acuerdo con ella, o marcaría como
  /// imposible una hora que la otra persona sí tiene marcada.
  static int bandOfHour(int hour) {
    if (hour < 14) return 0; // mañana
    if (hour < 20) return 1; // tarde
    return 2; // noche
  }

  static WeeklyAvailability fromJson(dynamic json) =>
      WeeklyAvailability((json as num?)?.toInt() ?? 0);
}
