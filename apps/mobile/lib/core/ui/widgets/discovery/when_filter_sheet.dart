import 'package:flutter/material.dart';

import 'package:match_point/core/ui/widgets/availability_picker.dart';
import 'package:match_point/features/onboarding/models/availability.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// "¿Cuándo puedes jugar?" — el filtro con el que ahora empieza la búsqueda.
///
/// Reutiliza a propósito la misma rejilla 7×3 con la que cada uno rellenó su
/// horario en el registro: la persona ya sabe usarla, y que la pregunta que
/// haces tenga la misma forma que la respuesta que diste es lo que hace
/// evidente qué se está cruzando con qué.
///
/// Devuelve `null` si se cierra sin aplicar.
Future<WeeklyAvailability?> showWhenFilterSheet(
  BuildContext context, {
  required WeeklyAvailability current,
}) {
  return showModalBottomSheet<WeeklyAvailability>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WhenFilterSheet(initial: current),
  );
}

/// Atajos para lo que la gente pide de verdad. Sin ellos, filtrar por
/// "el finde" son seis toques en la rejilla, y ese es exactamente el tipo de
/// fricción que hace que un filtro no se use nunca.
///
/// **Son interruptores, no botones**: se marcan y se desmarcan. Antes sólo
/// sumaban, así que tocar "Este finde" sin querer no había forma de deshacerlo
/// salvo repasando la rejilla casilla por casilla.
class _Preset {
  final String label;
  final int mask;
  const _Preset(this.label, this.mask);
}

/// Un atajo está marcado cuando **todos** sus huecos están puestos.
///
/// Se deduce de la máscara en vez de guardarse aparte: así la rejilla y los
/// atajos no pueden contradecirse. Si alguien marca a mano las seis casillas
/// del finde, "Este finde" se enciende solo, que es lo que uno espera al
/// mirarlo.
bool _isPresetOn(int mask, _Preset preset) =>
    mask & preset.mask == preset.mask;

/// Quitar un atajo, respetando lo que aporten los demás.
///
/// La resta no puede ser un `& ~preset`: con "Este finde" y "Por las noches"
/// marcados a la vez, quitar "noches" borraría también las noches del finde,
/// que las sostiene el otro atajo. Lo correcto es reconstruir la unión de los
/// que siguen marcados y sumarle lo que quede fuera del que se quita — o sea,
/// tratar los atajos como un OR de conjuntos, que es como se leen.
///
/// El último término conserva además lo pintado a mano en la rejilla: sin él,
/// desmarcar un atajo se llevaría por delante casillas que nadie había pedido
/// borrar.
int _withoutPreset(int mask, _Preset preset, List<_Preset> all) {
  var kept = 0;
  for (final other in all) {
    if (other == preset) continue;
    if (_isPresetOn(mask, other)) kept |= other.mask;
  }
  return kept | (mask & ~preset.mask);
}

int _slot(int day, int band) => 1 << (day * 3 + band);

final _presets = <_Preset>[
  _Preset(
    S.current.thisWeekend,
    _slot(5, 0) |
        _slot(5, 1) |
        _slot(5, 2) |
        _slot(6, 0) |
        _slot(6, 1) |
        _slot(6, 2),
  ),
  _Preset(
    S.current.weekdayEvenings,
    _slot(0, 1) | _slot(1, 1) | _slot(2, 1) | _slot(3, 1) | _slot(4, 1),
  ),
  _Preset(
    S.current.weekdayMornings,
    _slot(0, 0) | _slot(1, 0) | _slot(2, 0) | _slot(3, 0) | _slot(4, 0),
  ),
  _Preset(
    S.current.atNights,
    _slot(0, 2) |
        _slot(1, 2) |
        _slot(2, 2) |
        _slot(3, 2) |
        _slot(4, 2) |
        _slot(5, 2) |
        _slot(6, 2),
  ),
];

class _WhenFilterSheet extends StatefulWidget {
  final WeeklyAvailability initial;
  const _WhenFilterSheet({required this.initial});

  @override
  State<_WhenFilterSheet> createState() => _WhenFilterSheetState();
}

class _WhenFilterSheetState extends State<_WhenFilterSheet> {
  late WeeklyAvailability _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.current.whenCanYouPlay, style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(
              S.current.whenFilterHint,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  FilterChip(
                    label: Text(preset.label),
                    selected: _isPresetOn(_value.mask, preset),
                    showCheckmark: false,
                    onSelected: (on) => setState(() {
                      // Suma o resta según esté, y la resta respeta lo que
                      // sostengan los otros atajos (ver `_withoutPreset`).
                      _value = WeeklyAvailability(
                        on
                            ? _value.mask | preset.mask
                            : _withoutPreset(_value.mask, preset, _presets),
                      );
                    }),
                  ),
              ],
            ),

            const SizedBox(height: 20),
            AvailabilityPicker(
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                TextButton(
                  onPressed: _value.isEmpty
                      ? null
                      : () => setState(
                          () => _value = WeeklyAvailability.empty,
                        ),
                  child: Text(S.current.clearFilter),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_value),
                  child: Text(
                    _value.isEmpty
                        ? S.current.seeEveryone
                        : S.current.seeWhoCan(_value.count),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
