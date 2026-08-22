import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../../features/onboarding/models/availability.dart';

/// Rejilla semanal de "lo que suelo tener libre".
///
/// Siete columnas por tres filas. No pretende ser un calendario ni la verdad
/// de una semana concreta — es la referencia que verá quien vaya a proponerte
/// algo, para no elegir un hueco en el que nunca puedes.
///
/// Se puede arrastrar el dedo para marcar varias casillas de una pasada: son
/// veintiuna, y tocarlas una a una es justo la fricción que hace que nadie lo
/// rellene.
class AvailabilityPicker extends StatefulWidget {
  final WeeklyAvailability value;
  final ValueChanged<WeeklyAvailability> onChanged;

  const AvailabilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<AvailabilityPicker> createState() => _AvailabilityPickerState();
}

class _AvailabilityPickerState extends State<AvailabilityPicker> {
  /// Al arrastrar, todas las casillas que se tocan toman el mismo estado que
  /// la primera: si empezaste marcando, marcas; si empezaste desmarcando,
  /// borras. Alternar cada una por separado haría del arrastre una lotería.
  bool? _paintingOn;
  final _painted = <int>{};

  void _apply(int day, int band) {
    final b = WeeklyAvailability.bit(day, band);
    if (_painted.contains(b)) return;
    _painted.add(b);

    final on = _paintingOn ?? !widget.value.has(day, band);
    _paintingOn ??= on;

    final mask = on ? widget.value.mask | b : widget.value.mask & ~b;
    if (mask != widget.value.mask) {
      widget.onChanged(WeeklyAvailability(mask));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera de días.
        Row(
          children: [
            const SizedBox(width: 56),
            for (final d in WeeklyAvailability.days)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var band = 0; band < 3; band++) ...[
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  WeeklyAvailability.bands[band],
                  style: context.textStyles.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              for (var day = 0; day < 7; day++)
                Expanded(child: _cell(context, day, band)),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int band) {
    final on = widget.value.has(day, band);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _paintingOn = null;
        _painted.clear();
        _apply(day, band);
      },
      onTapUp: (_) => _endPaint(),
      onTapCancel: _endPaint,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: on
                  ? context.colors.primary
                  : context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: on
                    ? context.colors.primary
                    : context.colors.outlineVariant,
              ),
            ),
            child: on
                ? Icon(Icons.check, size: 14, color: context.colors.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }

  void _endPaint() {
    _paintingOn = null;
    _painted.clear();
  }
}

/// La rejilla en modo lectura: la de otra persona, sin poder tocarla.
///
/// Se enseña al proponer una quedada — que es el único momento en que este
/// dato sirve para algo.
class AvailabilityView extends StatelessWidget {
  final WeeklyAvailability value;

  const AvailabilityView({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 56),
            for (final d in WeeklyAvailability.days)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var band = 0; band < 3; band++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    WeeklyAvailability.bands[band],
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                for (var day = 0; day < 7; day++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: AspectRatio(
                        aspectRatio: 1.6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: value.has(day, band)
                                ? context.colors.primary
                                : context.colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
