import 'package:flutter/material.dart';

import '../../../location/geocoding_service.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/courts/models/tennis_club.dart';

/// Pregunta cómo se llama un sitio que OpenStreetMap no tiene nombrado,
/// con el nombre ya propuesto y editable.
///
/// En la práctica casi ninguna pista de tenis de OSM lleva etiqueta `name`
/// (3 de 106 cerca de Benalmádena, comprobado), así que sin esto todas las
/// propuestas llegaban como "Club de tenis" y quien las recibía no sabía a
/// dónde tenía que ir. Se propone la dirección real en vez de dejar el
/// campo vacío: casi siempre vale tal cual, y quien conozca el sitio puede
/// escribir cómo lo llama todo el mundo ("las pistas del polideportivo").
///
/// Devuelve el nombre elegido, o null si se cancela.
Future<String?> askPlaceName(
  BuildContext context, {
  required String suggestion,
  required int courtCount,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _NamePlaceDialog(suggestion: suggestion, courtCount: courtCount),
  );
}

/// Nombre a proponer para [club]: su dirección ya conocida si la hay, si no
/// una geocodificación inversa (una sola petición, sobre el sitio ya
/// elegido — Nominatim admite ~1 por segundo).
Future<String> suggestedPlaceName(
  TennisClub club, {
  String? alreadyResolved,
  GeocodingService? geocoding,
}) async {
  final address =
      alreadyResolved ??
      club.street ??
      await (geocoding ?? GeocodingService()).reverse(
        club.latitude,
        club.longitude,
      );
  return address == null ? 'Pistas de tenis' : 'Pistas de tenis · $address';
}

class _NamePlaceDialog extends StatefulWidget {
  final String suggestion;
  final int courtCount;

  const _NamePlaceDialog({required this.suggestion, required this.courtCount});

  @override
  State<_NamePlaceDialog> createState() => _NamePlaceDialogState();
}

class _NamePlaceDialogState extends State<_NamePlaceDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.suggestion,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    // 200 es el tope que valida el backend para `placeName`.
    Navigator.of(
      context,
    ).pop(name.length > 200 ? name.substring(0, 200) : name);
  }

  @override
  Widget build(BuildContext context) {
    final courts = widget.courtCount == 1
        ? '1 pista'
        : '${widget.courtCount} pistas';

    return AlertDialog(
      title: const Text('¿Cómo se llama este sitio?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OpenStreetMap tiene aquí $courts, pero sin nombre. Ponle uno '
            'para que la otra persona sepa dónde es — la ubicación exacta '
            'va igualmente en el mapa de la quedada.',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nombre del sitio'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
          child: const Text('Usar este sitio'),
        ),
      ],
    );
  }
}
