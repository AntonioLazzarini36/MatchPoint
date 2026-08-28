import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/features/onboarding/models/availability.dart';

void main() {
  group('horario semanal', () {
    // Lunes tarde+noche, miércoles mañana, jueves tarde: el mismo valor que
    // se comprobó contra el backend, para que un cambio en la numeración de
    // los bits salte aquí y no en producción.
    const mask = WeeklyAvailability(1094);

    test('cada bit cae en el día y la franja que dice', () {
      expect(mask.has(0, 1), isTrue); // lunes tarde
      expect(mask.has(0, 2), isTrue); // lunes noche
      expect(mask.has(0, 0), isFalse); // lunes mañana
      expect(mask.has(2, 0), isTrue); // miércoles mañana
      expect(mask.has(3, 1), isTrue); // jueves tarde
      expect(mask.count, 4);
    });

    test('los días sin nada marcado se distinguen de los que sí', () {
      expect(mask.hasAnyOn(DateTime.monday), isTrue);
      expect(mask.hasAnyOn(DateTime.tuesday), isFalse);
      expect(mask.bandsOn(DateTime.monday), {1, 2});
      expect(mask.bandsOn(DateTime.tuesday), isEmpty);
    });

    test('el texto de un día dice qué franjas, o que no suele poder', () {
      expect(
        mask.labelForDay(DateTime.monday),
        'Suele tener libre: tarde, noche',
      );
      expect(mask.labelForDay(DateTime.tuesday), 'No suele tener libre');
    });

    test('vacío no es "no puede nunca", es "no lo ha dicho"', () {
      expect(WeeklyAvailability.empty.isEmpty, isTrue);
      expect(WeeklyAvailability.empty.summary, 'Sin definir');
    });

    test('el corte de horas coincide con las franjas de la rejilla', () {
      // Si esto se desalinea, el selector de horas atenúa horas que la otra
      // persona sí tiene marcadas.
      // Mañana 6-12, tarde 13-18, noche 19+. Los bordes son lo que importa:
      // si esto se desalinea de lo que pinta el selector de hora, se marcan
      // como buenas horas que la otra persona no tiene, o al reves.
      expect(WeeklyAvailability.bandOfHour(9), 0);
      expect(WeeklyAvailability.bandOfHour(12), 0);
      expect(WeeklyAvailability.bandOfHour(13), 1);
      expect(WeeklyAvailability.bandOfHour(18), 1);
      expect(WeeklyAvailability.bandOfHour(19), 2);
      expect(WeeklyAvailability.bandOfHour(23), 2);
    });

    test('marcar y desmarcar una casilla es reversible', () {
      final on = WeeklyAvailability.empty.toggled(5, 2);
      expect(on.has(5, 2), isTrue);
      expect(on.toggled(5, 2).mask, 0);
    });
  });
}
