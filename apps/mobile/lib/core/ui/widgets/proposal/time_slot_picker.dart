import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../../features/onboarding/models/availability.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// "¿A qué hora?" — dos ruedas, hora y minutos.
///
/// Antes era una rejilla con **57 botones** (de 8:00 a 22:00, uno cada 15
/// min): había que buscar la hora con la vista entre casi sesenta cuadraditos
/// iguales, y encima no llegaba ni a las 7 de la mañana ni a las 11 de la
/// noche, que son horas a las que se juega. Ahora es el gesto que todo el
/// mundo tiene aprendido de poner una alarma.
///
/// Los minutos son **sólo 00/15/30/45**: nadie queda a las 9:38, y una rueda
/// de sesenta minutos deja elegirlo. De 6:00 a 24:00 porque fuera de ahí no
/// hay pista abierta.
///
/// Las horas a las que la otra persona **suele poder** se pintan en verde en
/// la propia rueda. Antes esto era una frase ("Lucía ese día suele tener
/// libre: tarde") que había que leer, traducir a horas y recordar mientras
/// buscabas en una rejilla de botones grises. Ahora es el mismo dato puesto
/// donde se toma la decisión, y sin una palabra.
///
/// Sólo se tiñe **la hora**, no los minutos: la rejilla del perfil habla de
/// franjas de media tarde, así que decir que las 18:15 sí y las 18:45 no
/// sería inventarse una precisión que ese dato no tiene.
///
/// No bloquea nada, igual que el paso del día: es lo que suele pasar, no su
/// agenda.
Future<TimeOfDay?> pickTimeSlot(
  BuildContext context, {
  DateTime? day,
  TimeOfDay? initial,
  WeeklyAvailability? otherAvailability,
  String? otherName,
}) {
  // Sin día elegido o con la rejilla en blanco no hay nada que pintar: una
  // rueda entera en verde diría "puede siempre", que no es lo que sabemos.
  final usual = (day == null ||
          otherAvailability == null ||
          otherAvailability.isEmpty)
      ? null
      : otherAvailability;

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TimeWheelSheet(
      initial: initial,
      freeHours: usual?.freeHoursOn(day!.weekday, fromHour: _minHour, toHour: _maxHour),
      otherName: otherName,
    ),
  );
}

/// Primera y última hora que se pueden proponer.
const _minHour = 6;
const _maxHour = 24;

/// Los únicos minutos elegibles.
const _minutes = [0, 15, 30, 45];

class _TimeWheelSheet extends StatefulWidget {
  final TimeOfDay? initial;

  /// Horas del reloj que la otra persona suele tener libres ese día. `null`
  /// cuando no se sabe — que no es lo mismo que un conjunto vacío, que
  /// significa "ese día no suele poder a ninguna hora".
  final Set<int>? freeHours;
  final String? otherName;

  const _TimeWheelSheet({this.initial, this.freeHours, this.otherName});

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _hourIndex;
  late int _minuteIndex;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    // Por defecto las 10:00: una hora a la que de verdad se juega. Arrancar a
    // las 6:00 obligaría a girar la rueda entera cada vez.
    final start = widget.initial ?? const TimeOfDay(hour: 10, minute: 0);
    final hour = widget.initial != null ? start.hour : _bestStartHour(start);
    _hourIndex = (hour - _minHour).clamp(0, _maxHour - _minHour);
    // El minuto que venga se ajusta al cuarto más cercano hacia abajo, para
    // que abrir el selector con una hora ya elegida no la mueva sola.
    _minuteIndex = _minutes.indexWhere((m) => m > start.minute) - 1;
    if (_minuteIndex < 0) _minuteIndex = _minutes.length - 1;

    _hourCtrl = FixedExtentScrollController(initialItem: _hourIndex);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  int get _hour => _minHour + _hourIndex;
  int get _minute => _minutes[_minuteIndex];

  Set<int> get _free => widget.freeHours ?? const {};
  bool _isFree(int hour) => _free.contains(hour);

  /// Arrancar en una hora que le venga bien a la otra persona ahorra el
  /// trabajo de buscarla. Si no se sabe nada, las 10:00 de siempre.
  int _bestStartHour(TimeOfDay fallback) {
    if (_free.isEmpty) return fallback.hour;
    if (_isFree(fallback.hour)) return fallback.hour;
    // La primera hora libre a partir de las 9, y si no, la primera del día.
    final sorted = _free.toList()..sort();
    return sorted.firstWhere((h) => h >= 9, orElse: () => sorted.first);
  }

  /// Las 24:00 son la medianoche del día siguiente, que como hora de inicio
  /// de un partido no tiene sentido: se deja elegir 24 como tope visual pero
  /// se devuelve 23:45, la última hora real.
  TimeOfDay get _value =>
      _hour >= 24 ? const TimeOfDay(hour: 23, minute: 45) : TimeOfDay(hour: _hour, minute: _minute);

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.current.atWhatTime, style: t.headlineSmall),
            if (_free.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Leyenda con la misma marca que llevan las horas, igual que en
              // el paso del día: se explica el color una vez y se calla.
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: colors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.otherName == null
                          ? S.current.hoursTheyCanUsually
                          : S.current.personUsuallyCanAtTheseHours(widget.otherName!),
                      style: t.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  // La banda que marca cuál es el valor elegido. Va detrás de
                  // las ruedas para que los números queden encima.
                  Center(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Wheel(
                        controller: _hourCtrl,
                        count: _maxHour - _minHour + 1,
                        selected: _hourIndex,
                        label: (i) => (_minHour + i).toString().padLeft(2, '0'),
                        highlighted: (i) => _isFree(_minHour + i),
                        onChanged: (i) => setState(() => _hourIndex = i),
                      ),
                      Text(
                        ':',
                        style: t.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _Wheel(
                        controller: _minuteCtrl,
                        count: _minutes.length,
                        selected: _minuteIndex,
                        // A las 24 no hay minutos que elegir.
                        enabled: _hour < 24,
                        label: (i) => _minutes[i].toString().padLeft(2, '0'),
                        onChanged: (i) => setState(() => _minuteIndex = i),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: Text(
                  S.current.proposeAt(
                    '${_value.hour.toString().padLeft(2, '0')}:'
                    '${_value.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Qué valores van resaltados (las horas a las que la otra persona suele
  /// poder). Sin esto, todos iguales.
  final bool Function(int)? highlighted;

  const _Wheel({
    required this.controller,
    required this.count,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 84,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 46,
        // Suficiente para que se vea que hay más arriba y abajo, sin
        // deformar tanto los números de los extremos que no se lean.
        perspective: 0.004,
        diameterRatio: 1.6,
        physics: enabled
            ? const FixedExtentScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, i) {
            final isSelected = i == selected;
            final isFree = highlighted?.call(i) ?? false;

            final Color color;
            if (!enabled) {
              color = colors.outline.withValues(alpha: 0.4);
            } else if (isSelected) {
              color = colors.primary;
            } else if (isFree) {
              color = colors.onPrimaryContainer;
            } else {
              color = colors.onSurfaceVariant;
            }

            return Center(
              child: Container(
                // La pastilla verde sólo en las horas buenas que no son la
                // elegida: sobre la banda de selección se solaparían dos
                // fondos y no se sabría cuál manda.
                decoration: isFree && !isSelected
                    ? BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      )
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: Text(
                  label(i),
                  style: context.textStyles.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: isSelected || isFree
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
