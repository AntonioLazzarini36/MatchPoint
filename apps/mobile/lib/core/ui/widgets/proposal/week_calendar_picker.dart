import 'package:flutter/material.dart';

import '../../../../features/onboarding/models/availability.dart';

/// Week-view date picker: 7 days in a row, Monday-first, with prev/next
/// week navigation. Can't go to a week entirely before the current one
/// (can't propose a session in the past); individual past days within the
/// current week are shown but disabled. Forward navigation is unbounded.
/// Shared between the tennis court-map proposal flow and the running
/// proposal flow - same "pick a day" step for both sports.
///
/// Cuando se le pasa el horario habitual de la otra persona
/// ([otherAvailability]), los días que esa persona **no** suele tener libres
/// se marcan como tales. No se bloquean: es una referencia de lo que suele
/// pasar, no su agenda — y un sábado que normalmente trabaja puede tenerlo
/// libre justo esta semana. Lo que se evita es proponer a ciegas un hueco en
/// el que casi nunca puede, que es lo que quema dos o tres mensajes antes de
/// llegar a jugar.
class WeekCalendarPicker extends StatefulWidget {
  final WeeklyAvailability? otherAvailability;
  final String? otherName;

  const WeekCalendarPicker({super.key, this.otherAvailability, this.otherName});

  @override
  State<WeekCalendarPicker> createState() => _WeekCalendarPickerState();
}

class _WeekCalendarPickerState extends State<WeekCalendarPicker> {
  static const _weekdaysShort = [
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  late final DateTime _today;
  late final DateTime _currentWeekStart;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _currentWeekStart = _mondayOf(_today);
    _weekStart = _currentWeekStart;
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  bool get _isCurrentWeek => _weekStart == _currentWeekStart;

  void _goToPreviousWeek() {
    if (_isCurrentWeek) return;
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  }

  void _goToNextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final weekEnd = days.last;
    final sameMonth = _weekStart.month == weekEnd.month;
    final rangeLabel = sameMonth
        ? '${_weekStart.day}-${weekEnd.day} de ${_months[_weekStart.month - 1]}'
        : '${_weekStart.day} ${_months[_weekStart.month - 1]} - '
              '${weekEnd.day} ${_months[weekEnd.month - 1]}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Qué día?', style: Theme.of(context).textTheme.titleMedium),
            if (_usual != null) ...[
              const SizedBox(height: 4),
              Text(
                '${widget.otherName ?? 'Esta persona'} suele tener libre: '
                '${_usual!.summary.toLowerCase()}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _isCurrentWeek ? null : _goToPreviousWeek,
                ),
                Text(rangeLabel, style: Theme.of(context).textTheme.bodyMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _goToNextWeek,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(children: [for (final day in days) _buildDayCell(day)]),
            if (_usual != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.remove_circle_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Los días en gris no los suele tener libres. Puedes '
                      'proponerlos igual.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// El horario de la otra persona, sólo si lo ha rellenado: una rejilla
  /// vacía significa "no lo ha dicho", y pintar entonces la semana entera en
  /// gris diría que nunca puede, que es lo contrario de lo que sabemos.
  WeeklyAvailability? get _usual {
    final a = widget.otherAvailability;
    return (a == null || a.isEmpty) ? null : a;
  }

  Widget _buildDayCell(DateTime day) {
    final isPast = day.isBefore(_today);
    final isToday = day == _today;
    final scheme = Theme.of(context).colorScheme;
    final unusual = _usual != null && !_usual!.hasAnyOn(day.weekday);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isToday ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isPast ? null : () => Navigator.of(context).pop(day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    _weekdaysShort[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      color: isPast ? scheme.outline : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: (isPast || unusual)
                          ? scheme.outline
                          : (isToday
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface),
                    ),
                  ),
                  if (_usual != null && !isPast) ...[
                    const SizedBox(height: 5),
                    Container(
                      height: 4,
                      width: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unusual ? scheme.outlineVariant : scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
