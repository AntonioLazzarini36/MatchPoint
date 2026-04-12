import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DiscoveryModeToggle extends StatelessWidget {
  final bool isPartnerMode;
  final ValueChanged<bool> onChanged;

  const DiscoveryModeToggle({
    super.key,
    required this.isPartnerMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value, Color activeColor) {
      final active = isPartnerMode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? activeColor : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: context.textStyles.titleSmall?.copyWith(
                  color: active ? activeColor : context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          tab('Partner', true, context.colors.primary),
          tab('Match', false, context.colors.tertiary),
        ],
      ),
    );
  }
}
