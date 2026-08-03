import 'package:flutter/material.dart';

/// Week-view date picker: 7 days in a row, Monday-first, with prev/next
/// week navigation. Can't go to a week entirely before the current one
/// (can't propose a session in the past); individual past days within the
/// current week are shown but disabled. Forward navigation is unbounded.
/// Shared between the tennis court-map proposal flow and the running
/// proposal flow - same "pick a day" step for both sports.
class WeekCalendarPicker extends StatefulWidget {
  const WeekCalendarPicker({super.key});

  @override
  State<WeekCalendarPicker> createState() => _WeekCalendarPickerState();
}

class _WeekCalendarPickerState extends State<WeekCalendarPicker> {
  static const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
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
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final isPast = day.isBefore(_today);
    final isToday = day == _today;
    final scheme = Theme.of(context).colorScheme;

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
                      color: isPast
                          ? scheme.outline
                          : (isToday ? scheme.onPrimaryContainer : scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
