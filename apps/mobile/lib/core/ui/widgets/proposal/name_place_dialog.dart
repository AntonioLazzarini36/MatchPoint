import 'package:flutter/material.dart';

import '../../../location/geocoding_service.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/courts/models/tennis_club.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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
  return address == null ? S.current.tennisCourts : S.current.tennisCourtsAt(address);
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
        : S.current.courtsCount(widget.courtCount);

    return AlertDialog(
      title: Text(S.current.whatIsThisPlaceCalled),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.current.osmHasCourtsNoName(courts),
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
            decoration: InputDecoration(labelText: S.current.placeName),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.current.cancel),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
          child: Text(S.current.useThisPlace),
        ),
      ],
    );
  }
}
