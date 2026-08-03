import 'package:flutter/material.dart';

/// 8:00 a 22:00 en franjas de 15 min - un slider/reloj completo es
/// overkill para "propon una hora orientativa", esto se elige de un
/// vistazo. Compartido entre la propuesta de tenis (club) y la de correr
/// (sin club, solo punto de encuentro opcional) - mismo paso "a que hora"
/// para las dos.
Future<TimeOfDay?> pickTimeSlot(BuildContext context) async {
  final slots = <TimeOfDay>[
    for (var m = 8 * 60; m <= 22 * 60; m += 15)
      TimeOfDay(hour: m ~/ 60, minute: m % 60),
  ];

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
                  return OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(slot),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
