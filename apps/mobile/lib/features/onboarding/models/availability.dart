/// Cuándo puede jugar alguien (`Profile.availability`).
///
/// Franjas gruesas y no un calendario, a propósito: lo que hace falta saber
/// es si dos personas **pueden coincidir**, y pedir más detalle sólo consigue
/// que nadie lo rellene — y un perfil vacío no ordena nada.
///
/// Es el dato que más partidos desbloquea. La app ya filtraba por nivel y por
/// distancia, pero dos personas del mismo nivel a dos kilómetros no juegan
/// nunca si una puede los martes por la mañana y la otra los sábados.
enum AvailabilitySlot {
  weekdayMorning,
  weekdayAfternoon,
  weekdayEvening,
  weekendMorning,
  weekendAfternoon,
  weekendEvening,
}

extension AvailabilitySlotApi on AvailabilitySlot {
  String get apiValue {
    switch (this) {
      case AvailabilitySlot.weekdayMorning:
        return 'WEEKDAY_MORNING';
      case AvailabilitySlot.weekdayAfternoon:
        return 'WEEKDAY_AFTERNOON';
      case AvailabilitySlot.weekdayEvening:
        return 'WEEKDAY_EVENING';
      case AvailabilitySlot.weekendMorning:
        return 'WEEKEND_MORNING';
      case AvailabilitySlot.weekendAfternoon:
        return 'WEEKEND_AFTERNOON';
      case AvailabilitySlot.weekendEvening:
        return 'WEEKEND_EVENING';
    }
  }

  /// Si es de entre semana. Se usa para agrupar la rejilla en dos columnas,
  /// que es como la gente piensa su semana.
  bool get isWeekday => index < 3;

  /// El tramo del día, sin repetir "entre semana"/"finde" en cada casilla.
  String get timeLabel {
    switch (this) {
      case AvailabilitySlot.weekdayMorning:
      case AvailabilitySlot.weekendMorning:
        return 'Mañanas';
      case AvailabilitySlot.weekdayAfternoon:
      case AvailabilitySlot.weekendAfternoon:
        return 'Tardes';
      case AvailabilitySlot.weekdayEvening:
      case AvailabilitySlot.weekendEvening:
        return 'Noches';
    }
  }

  /// Nombre completo, para cuando aparece suelto (en un perfil, por ejemplo).
  String get label =>
      '${timeLabel.toLowerCase()} ${isWeekday ? 'entre semana' : 'de fin de semana'}';

  static AvailabilitySlot? fromApi(Object? v) {
    switch (v?.toString()) {
      case 'WEEKDAY_MORNING':
        return AvailabilitySlot.weekdayMorning;
      case 'WEEKDAY_AFTERNOON':
        return AvailabilitySlot.weekdayAfternoon;
      case 'WEEKDAY_EVENING':
        return AvailabilitySlot.weekdayEvening;
      case 'WEEKEND_MORNING':
        return AvailabilitySlot.weekendMorning;
      case 'WEEKEND_AFTERNOON':
        return AvailabilitySlot.weekendAfternoon;
      case 'WEEKEND_EVENING':
        return AvailabilitySlot.weekendEvening;
      default:
        return null;
    }
  }

  static List<AvailabilitySlot> listFromJson(dynamic json) {
    if (json is! List) return const [];
    return json
        .map(AvailabilitySlotApi.fromApi)
        .whereType<AvailabilitySlot>()
        .toList();
  }
}

/// Resumen corto para una fila o una tarjeta: "Tardes y noches entre semana"
/// se lee mejor que seis etiquetas sueltas.
String availabilitySummary(List<AvailabilitySlot> slots) {
  if (slots.isEmpty) return 'Sin definir';
  if (slots.length == AvailabilitySlot.values.length) return 'Casi siempre';

  final weekday = slots.where((s) => s.isWeekday).toList();
  final weekend = slots.where((s) => !s.isWeekday).toList();

  String group(List<AvailabilitySlot> g, String when) {
    final names = g.map((s) => s.timeLabel.toLowerCase()).toList();
    final joined = names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
    return '$joined $when';
  }

  final parts = <String>[
    if (weekday.isNotEmpty) group(weekday, 'entre semana'),
    if (weekend.isNotEmpty) group(weekend, 'en finde'),
  ];
  final text = parts.join(' · ');
  return text[0].toUpperCase() + text.substring(1);
}
