import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../../features/onboarding/models/availability.dart';

/// Rejilla para elegir cuándo puedes jugar.
///
/// Dos columnas —entre semana y fin de semana— porque es como la gente piensa
/// su semana, y tres filas de tramo. Seis casillas en total: el objetivo es
/// que se rellene de un vistazo, no capturar un horario exacto. Un calendario
/// daría más precisión y conseguiría que nadie lo tocara.
class AvailabilityPicker extends StatelessWidget {
  final Set<AvailabilitySlot> selected;
  final ValueChanged<Set<AvailabilitySlot>> onChanged;

  const AvailabilityPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(AvailabilitySlot slot) {
    final next = Set<AvailabilitySlot>.from(selected);
    if (!next.remove(slot)) next.add(slot);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final weekday = AvailabilitySlot.values.where((s) => s.isWeekday).toList();
    final weekend = AvailabilitySlot.values.where((s) => !s.isWeekday).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(context, 'Entre semana', weekday)),
        const SizedBox(width: 12),
        Expanded(child: _column(context, 'Fin de semana', weekend)),
      ],
    );
  }

  Widget _column(
    BuildContext context,
    String title,
    List<AvailabilitySlot> slots,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final slot in slots) ...[
          _cell(context, slot),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, AvailabilitySlot slot) {
    final on = selected.contains(slot);
    return InkWell(
      onTap: () => _toggle(slot),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: on ? context.colors.primary : context.colors.surface,
          border: Border.all(
            color: on ? context.colors.primary : context.colors.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: on ? context.colors.onPrimary : context.colors.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                slot.timeLabel,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: on
                      ? context.colors.onPrimary
                      : context.colors.onSurface,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
