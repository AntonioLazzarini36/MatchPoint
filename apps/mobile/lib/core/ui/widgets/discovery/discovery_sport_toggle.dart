import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/sport.dart';

class DiscoverySportToggle extends StatelessWidget {
  final Sport selected;
  final ValueChanged<Sport> onChanged;

  const DiscoverySportToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _item(context, Sport.tennis, Icons.sports_tennis),
          _item(context, Sport.running, Icons.directions_run),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, Sport sport, IconData icon) {
    final isSelected = selected == sport;
    return GestureDetector(
      onTap: () => onChanged(sport),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              sport.label,
              style: context.textStyles.labelMedium?.copyWith(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
