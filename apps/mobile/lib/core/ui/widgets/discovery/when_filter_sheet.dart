import 'package:flutter/material.dart';

import 'package:match_point/core/ui/widgets/availability_picker.dart';
import 'package:match_point/features/onboarding/models/availability.dart';

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
class _Preset {
  final String label;
  final int mask;
  const _Preset(this.label, this.mask);
}

int _slot(int day, int band) => 1 << (day * 3 + band);

final _presets = <_Preset>[
  _Preset(
    'Este finde',
    _slot(5, 0) |
        _slot(5, 1) |
        _slot(5, 2) |
        _slot(6, 0) |
        _slot(6, 1) |
        _slot(6, 2),
  ),
  _Preset(
    'Entre semana, tardes',
    _slot(0, 1) | _slot(1, 1) | _slot(2, 1) | _slot(3, 1) | _slot(4, 1),
  ),
  _Preset(
    'Entre semana, mañanas',
    _slot(0, 0) | _slot(1, 0) | _slot(2, 0) | _slot(3, 0) | _slot(4, 0),
  ),
  _Preset(
    'Por las noches',
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
            Text('¿Cuándo puedes jugar?', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Te enseñamos primero a quien le venga bien lo mismo que a ti. '
              'Marca las franjas en las que sueles tener libre.',
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    label: Text(preset.label),
                    onPressed: () => setState(
                      // Suma, no reemplaza: encadenar "este finde" y "por las
                      // noches" es una petición razonable y perder lo anterior
                      // en cada toque haría los atajos inútiles juntos.
                      () => _value = WeeklyAvailability(
                        _value.mask | preset.mask,
                      ),
                    ),
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
                  child: const Text('Quitar filtro'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_value),
                  child: Text(
                    _value.isEmpty
                        ? 'Ver a todo el mundo'
                        : 'Ver quién puede (${_value.count})',
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
