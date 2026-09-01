import 'package:flutter/material.dart';

import '../../../../features/onboarding/models/availability.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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
  /// Tenía su propia copia de los días y los meses en castellano, así que
  /// esta pantalla se quedaba sin traducir aunque el resto de la app
  /// cambiara. Ahora salen de `S`, como todo lo demás.
  static List<String> get _weekdaysShort => S.current.weekdayShort;
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
            // Sin frase debajo. Decia "Lucia suele tener libre: tarde LMXJ,
            // mañana SD", que es la misma informacion que ya esta pintada en
            // los propios dias y ademas en un formato que hay que descifrar.
            // Lo que se ve se entiende antes que lo que se lee.
            Text(S.current.whatDay, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
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
            const SizedBox(height: 6),
            Row(children: [for (final day in days) _buildDayCell(day)]),
            if (_usual != null) ...[
              const SizedBox(height: 14),
              // Leyenda con la misma marca que llevan los dias, en vez de una
              // frase describiendo el horario: explica el codigo de color una
              // vez y se calla.
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.otherName == null
                          ? S.current.daysTheyUsuallyHaveFree
                          : S.current.personUsuallyFreeTheseDays(widget.otherName!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

  /// Un dia de la semana.
  ///
  /// Los numeros iban todos en el mismo gris y la disponibilidad era un punto
  /// de cuatro pixeles debajo: habia que saber que ese punto significaba algo
  /// para llegar a verlo. Ahora **el dia que la otra persona suele tener libre
  /// se pinta entero** —fondo verde claro y numero en negrita— y el que no, se
  /// queda plano. Se distingue de un vistazo y sin leer nada.
  ///
  /// Sigue sin bloquear ninguno: es lo que *suele* pasar, no su agenda, y un
  /// sabado que normalmente trabaja puede tenerlo libre justo esta semana.
  Widget _buildDayCell(DateTime day) {
    final isPast = day.isBefore(_today);
    final isToday = day == _today;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final free = _usual != null && _usual!.hasAnyOn(day.weekday) && !isPast;

    final Color background;
    final Color numberColor;
    if (isPast) {
      background = Colors.transparent;
      numberColor = scheme.outline;
    } else if (free) {
      background = scheme.primaryContainer;
      numberColor = scheme.onPrimaryContainer;
    } else {
      background = Colors.transparent;
      numberColor = scheme.onSurface;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isPast ? null : () => Navigator.of(context).pop(day),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // Hoy se marca con un borde y no con relleno, para no chocar
                // con el relleno que ya significa "suele tener libre".
                border: isToday
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    _weekdaysShort[day.weekday - 1],
                    style: t.labelMedium?.copyWith(
                      color: isPast ? scheme.outline : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: t.titleMedium?.copyWith(
                      fontWeight: free || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: numberColor,
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
