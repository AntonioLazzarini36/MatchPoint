import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/utils/slot_suggestions.dart';
import 'package:match_point/features/onboarding/models/availability.dart';

/// `bit = día * 3 + franja`, lunes = 0.
WeeklyAvailability av(List<(int, int)> slots) {
  var mask = 0;
  for (final (d, b) in slots) {
    mask |= 1 << (d * 3 + b);
  }
  return WeeklyAvailability(mask);
}

void main() {
  // Un lunes, para que los días de la semana salgan donde se espera.
  final lunes = DateTime(2026, 8, 31, 8);

  test('sugiere sólo lo que coincide en los dos horarios', () {
    // Yo: sábado mañana y martes tarde. La otra persona: sábado mañana y
    // jueves noche. Lo único común es el sábado por la mañana.
    final s = suggestSlots(
      mine: av([(5, 0), (1, 1)]),
      theirs: av([(5, 0), (3, 2)]),
      from: lunes,
    );

    expect(s, isNotEmpty);
    expect(
      s.every((x) => x.day.weekday == DateTime.saturday && x.band == 0),
      isTrue,
      reason: 'sólo debería salir el sábado por la mañana',
    );
  });

  test('sin coincidencias no se inventa nada', () {
    final s = suggestSlots(
      mine: av([(0, 0)]), // lunes mañana
      theirs: av([(4, 2)]), // viernes noche
      from: lunes,
    );
    expect(s, isEmpty);
  });

  test('si alguno no ha rellenado su horario, no hay sugerencias', () {
    expect(
      suggestSlots(mine: WeeklyAvailability.empty, theirs: av([(5, 0)]), from: lunes),
      isEmpty,
    );
    expect(
      suggestSlots(mine: av([(5, 0)]), theirs: WeeklyAvailability.empty, from: lunes),
      isEmpty,
    );
  });

  test('lo que antes ocurre va primero', () {
    // Coinciden en lunes-tarde y sábado-mañana. Empezando en lunes, el lunes
    // de hoy tiene que ir antes que el sábado.
    final s = suggestSlots(
      mine: av([(0, 1), (5, 0)]),
      theirs: av([(0, 1), (5, 0)]),
      from: lunes,
    );
    expect(s.first.day.weekday, DateTime.monday);
    expect(s[1].day.weekday, DateTime.saturday);
  });

  test('no propone una hora que ya ha pasado hoy', () {
    // Las 21:00 de un lunes en el que los dos tienen libre la mañana: la
    // mañana de hoy ya no vale, tiene que saltar al lunes siguiente.
    final lunesNoche = DateTime(2026, 8, 31, 21);
    final s = suggestSlots(
      mine: av([(0, 0)]),
      theirs: av([(0, 0)]),
      from: lunesNoche,
    );

    expect(s, isNotEmpty);
    expect(
      s.first.day.isAfter(DateTime(2026, 8, 31)),
      isTrue,
      reason: 'proponer un partido para esta mañana es peor que no sugerir',
    );
  });

  test('la hora sugerida cae dentro de su propia franja', () {
    // Si esto se desalinea de `bandOfHour`, la sugerencia diria "tarde" y
    // luego el selector pintaria esa hora como de otra franja.
    final s = suggestSlots(
      mine: av([(5, 0), (5, 1), (5, 2)]),
      theirs: av([(5, 0), (5, 1), (5, 2)]),
      from: lunes,
    );

    expect(s, isNotEmpty);
    for (final slot in s) {
      expect(
        WeeklyAvailability.bandOfHour(slot.hour),
        slot.band,
        reason: '${slot.hour}:00 no cae en la franja ${slot.bandLabel}',
      );
    }
  });

  test('no devuelve mas de las pedidas', () {
    final todo = av([
      for (var d = 0; d < 7; d++)
        for (var b = 0; b < 3; b++) (d, b),
    ]);
    expect(suggestSlots(mine: todo, theirs: todo, from: lunes, limit: 3).length, 3);
  });
}
