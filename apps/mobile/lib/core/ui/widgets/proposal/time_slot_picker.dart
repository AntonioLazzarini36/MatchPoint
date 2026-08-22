import 'package:flutter/material.dart';

import '../../../../features/onboarding/models/availability.dart';

/// 8:00 a 22:00 en franjas de 15 min - un slider/reloj completo es
/// overkill para "propon una hora orientativa", esto se elige de un
/// vistazo. Compartido entre la propuesta de tenis (club) y la de correr
/// (sin club, solo punto de encuentro opcional) - mismo paso "a que hora"
/// para las dos.
///
/// Si se conoce el horario habitual de la otra persona ([otherAvailability])
/// las horas que caen fuera de lo que suele tener libre **ese día** se
/// atenuan. Siguen pulsables a proposito: es una referencia, no su agenda.
Future<TimeOfDay?> pickTimeSlot(
  BuildContext context, {
  DateTime? day,
  WeeklyAvailability? otherAvailability,
  String? otherName,
}) async {
  final slots = <TimeOfDay>[
    for (var m = 8 * 60; m <= 22 * 60; m += 15)
      TimeOfDay(hour: m ~/ 60, minute: m % 60),
  ];

  // Sin dia o sin horario relleno no hay nada que atenuar: se pinta la
  // rejilla de siempre.
  final usual =
      (day == null || otherAvailability == null || otherAvailability.isEmpty)
      ? null
      : otherAvailability;
  final freeBands = usual?.bandsOn(day!.weekday) ?? const <int>{};

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿A qué hora?',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            if (usual != null) ...[
              const SizedBox(height: 4),
              Text(
                freeBands.isEmpty
                    ? '${otherName ?? 'Esta persona'} no suele tener libre '
                          'ese día.'
                    : '${otherName ?? 'Esta persona'} ese día suele tener '
                          'libre: ${usual.labelForDay(day!.weekday).replaceFirst('Suele tener libre: ', '')}.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 88,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.0,
                ),
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final slot = slots[i];
                  final label =
                      '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                  final unusual =
                      usual != null &&
                      !freeBands.contains(
                        WeeklyAvailability.bandOfHour(slot.hour),
                      );
                  final scheme = Theme.of(context).colorScheme;

                  return OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(slot),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: unusual ? scheme.outline : null,
                      side: unusual
                          ? BorderSide(color: scheme.outlineVariant)
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, maxLines: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
