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

  /// Una clave por casilla para poder resolver qué casilla hay bajo el dedo.
  /// El gesto vive en la rejilla entera y no en cada casilla porque un
  /// `GestureDetector` por casilla sólo recibe los eventos del dedo que
  /// empezó dentro de él: al arrastrar hasta la de al lado, esa no se entera
  /// de nada. Era exactamente el fallo — se podía tocar, pero no arrastrar.
  final _cellKeys = List.generate(21, (_) => GlobalKey());

  int? _cellAt(Offset globalPosition) {
    for (var i = 0; i < _cellKeys.length; i++) {
      final box = _cellKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  void _paintAt(Offset globalPosition) {
    final index = _cellAt(globalPosition);
    if (index == null) return;
    _apply(index ~/ 3, index % 3);
  }

  /// La máscara que se está construyendo durante un gesto.
  ///
  /// Hace falta porque `widget.value` no cambia hasta que el padre
  /// reconstruye, y eso ocurre en el frame siguiente: dos casillas pintadas
  /// dentro del mismo frame partían las dos del valor viejo, así que la
  /// segunda borraba lo que acababa de marcar la primera. Se veía como que
  /// el arrastre marcaba todas menos la primera.
  int? _pending;

  int get _currentMask => _pending ?? widget.value.mask;

  void _apply(int day, int band) {
    final b = WeeklyAvailability.bit(day, band);
    if (_painted.contains(b)) return;
    _painted.add(b);

    final on = _paintingOn ?? (_currentMask & b == 0);
    _paintingOn ??= on;

    final mask = on ? _currentMask | b : _currentMask & ~b;
    if (mask != _currentMask) {
      _pending = mask;
      widget.onChanged(WeeklyAvailability(mask));
    }
  }

  void _startPaint() {
    _paintingOn = null;
    _painted.clear();
    // El valor puede haber cambiado desde fuera entre un gesto y el
    // siguiente, así que cada gesto vuelve a partir de `widget.value`.
    _pending = null;
  }

  /// Dónde bajó el dedo. Un arrastre no se reconoce hasta que te has movido
  /// unos píxeles, y para entonces el dedo ya ha salido de la casilla en la
  /// que empezó: sin esto, esa primera casilla no se pintaba nunca.
  Offset? _downAt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // El toque se resuelve al levantar el dedo y no al bajarlo: bajándolo
      // se marcaría una casilla cada vez que alguien arrastra la página para
      // hacer scroll pasando por encima de la rejilla.
      onTapUp: (d) {
        _startPaint();
        _paintAt(d.globalPosition);
      },
      // Un arrastre horizontal (marcar "toda la semana por la tarde") gana
      // al scroll vertical de la página, que es el reparto que quiere el
      // usuario: para desplazarse arrastra en vertical, para pintar cruza.
      onPanDown: (d) => _downAt = d.globalPosition,
      onPanStart: (d) {
        _startPaint();
        final from = _downAt;
        if (from != null) _paintAt(from);
        _paintAt(d.globalPosition);
      },
      onPanUpdate: (d) => _paintAt(d.globalPosition),
      onPanEnd: (_) => _startPaint(),
      onPanCancel: _startPaint,
      child: Column(
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
      ),
    );
  }

  Widget _cell(BuildContext context, int day, int band) {
    final on = widget.value.has(day, band);

    return Padding(
      key: _cellKeys[day * 3 + band],
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          key: ValueKey('avail-$day-$band'),
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
    );
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
