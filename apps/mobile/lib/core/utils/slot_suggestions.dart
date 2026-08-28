import '../../features/onboarding/models/availability.dart';

/// Un hueco concreto que se le puede proponer a alguien: día real del
/// calendario y hora, no "sábado por la mañana" en abstracto.
class SlotSuggestion {
  final DateTime day;

  /// Franja del horario semanal (0 mañana, 1 tarde, 2 noche).
  final int band;

  /// La hora a la que se propone dentro de esa franja. Ver [_bandStartHour].
  final int hour;

  const SlotSuggestion({
    required this.day,
    required this.band,
    required this.hour,
  });

  String get bandLabel => WeeklyAvailability.bands[band];

  /// "Viernes 4 · noche".
  ///
  /// **Sin la hora.** La sugerencia propone una franja, no un minuto: decir
  /// "viernes noche a las 20:00" hace pensar que ese 20:00 significa algo,
  /// cuando es una convencion nuestra (ver [_bandStartHour]). La hora se
  /// elige en el paso siguiente, que es donde se puede mover.
  ///
  /// El numero del dia si se queda: con dos semanas por delante puede haber
  /// dos viernes, y "viernes noche" a secas no diria cual.
  String get label {
    final name = WeeklyAvailability.dayNames[day.weekday - 1];
    return '$name ${day.day} · ${bandLabel.toLowerCase()}';
  }
}

/// A qué hora se propone dentro de cada franja.
///
/// La rejilla del perfil dice "tarde", no "18:30", así que hay que elegir una
/// hora concreta y cualquier elección es una convención — por eso la
/// sugerencia **no la enseña** y sólo habla de la franja (ver [label]): se usa
/// como punto de partida del selector de hora, donde sí se puede mover.
///
/// Es el principio de cada franja (`bandOfHour`: 6-12, 13-18, 19+), que es lo
/// que alguien espera al leer "por la mañana": si el día que te viene bien es
/// por la mañana, el selector se abre a las 8 y subes desde ahí, en vez de
/// abrirse a media franja y tener que bajar.
int _bandStartHour(int band) => switch (band) {
  0 => 8, // mañana
  1 => 14, // tarde
  _ => 19, // noche
};

/// Los mejores huecos para proponerle un partido a alguien.
///
/// **Este es el "cuándo" que la app promete y hasta ahora no daba.** El
/// horario semanal de cada uno estaba en su perfil, el feed ya ordenaba por
/// cuántas franjas se comparten... y luego, al proponer, había que abrir un
/// calendario en blanco y adivinar. Cruzar las dos rejillas es una operación
/// de un `&`, y convierte "creo que los sábados le venían bien" en "sábado 30
/// a las 10:00".
///
/// El orden es **primero lo que antes ocurre**, no "lo mejor" según ninguna
/// puntuación inventada: entre dos huecos que os vienen bien a los dos, el de
/// esta semana vale más que el de la que viene, y no hay ningún otro dato con
/// el que romper el empate honestamente. Dentro del mismo día, por franja
/// (mañana antes que tarde antes que noche).
///
/// Devuelve lista vacía si alguno de los dos no ha rellenado su horario, o si
/// no coincidís en nada: en los dos casos lo correcto es no sugerir nada y
/// dejar el calendario normal, no inventarse un hueco.
List<SlotSuggestion> suggestSlots({
  required WeeklyAvailability mine,
  required WeeklyAvailability theirs,
  DateTime? from,
  int daysAhead = 14,
  int limit = 4,
}) {
  if (mine.isEmpty || theirs.isEmpty) return const [];

  final shared = mine.intersect(theirs);
  if (shared.isEmpty) return const [];

  final now = from ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final out = <SlotSuggestion>[];
  for (var offset = 0; offset <= daysAhead; offset++) {
    final day = today.add(Duration(days: offset));

    for (var band = 0; band < 3; band++) {
      if (!shared.has(day.weekday - 1, band)) continue;

      final hour = _bandStartHour(band);
      // Hoy sólo cuentan las franjas que aún no han pasado: proponer un
      // partido para hace tres horas es peor que no sugerir nada. Se exige
      // además una hora de margen, porque avisar con quince minutos no le
      // sirve a nadie.
      if (offset == 0 && hour <= now.hour + 1) continue;

      out.add(SlotSuggestion(day: day, band: band, hour: hour));
      if (out.length >= limit) return out;
    }
  }

  return out;
}
