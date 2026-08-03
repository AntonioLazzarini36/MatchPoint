import 'package:flutter/material.dart';

import '../../../location/location_result.dart';
import '../../location/location_search_screen.dart';
import '../../../network/api.dart';
import '../../../utils/date_format_es.dart';
import 'week_calendar_picker.dart';
import 'time_slot_picker.dart';
import '../../../../features/matches/services/chat_service.dart';

/// Correr no tiene "club"/pista que elegir (a diferencia de tenis, ver
/// TennisCourtsMapScreen) - el punto de encuentro es opcional, y si se
/// elige, es un sitio cualquiera (parque, calle, punto de partida), no
/// algo buscable en Overpass. Mismo patron de fondo que la propuesta de
/// tenis (dia + hora + mensaje al chat), pero sin mapa/lista de clubes:
/// se dispara directo desde el chat de ese match, no hace falta elegir
/// "a quien" porque ya estamos en su chat.
class _MeetingPointChoice {
  /// null = "sin punto de encuentro", explicito (no confundir con
  /// cancelar el flujo entero, que se maneja devolviendo null desde el
  /// propio bottom sheet).
  final LocationResult? location;
  const _MeetingPointChoice(this.location);
}

Future<void> proposeRunningSession(
  BuildContext context, {
  required String matchId,
}) async {
  final meetingChoice = await showModalBottomSheet<_MeetingPointChoice>(
    context: context,
    builder: (_) => const _MeetingPointSheet(),
  );
  if (meetingChoice == null || !context.mounted) return;

  final day = await showModalBottomSheet<DateTime>(
    context: context,
    builder: (_) => const WeekCalendarPicker(),
  );
  if (day == null || !context.mounted) return;

  final time = await pickTimeSlot(context);
  if (time == null || !context.mounted) return;

  final proposedAt = DateTime(
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  );
  final location = meetingChoice.location;
  final messenger = ScaffoldMessenger.of(context);

  try {
    final when = formatProposalDateTime(proposedAt);
    final text = location == null
        ? '¿Salimos a correr el $when?'
        : '¿Salimos a correr el $when? '
              'Punto de encuentro: ${location.displayName} '
              'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';

    await ChatService(Api.client).sendMessage(matchId: matchId, text: text);
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Propuesta enviada')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
  }
}

class _MeetingPointSheet extends StatelessWidget {
  const _MeetingPointSheet();

  Future<void> _choosePlace(BuildContext context) async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop(_MeetingPointChoice(result));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Punto de encuentro?', style: t.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Opcional - podéis quedar sin marcar un sitio fijo.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _choosePlace(context),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Elegir punto de encuentro'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _MeetingPointChoice(null)),
                child: const Text('Proponer sin punto de encuentro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
