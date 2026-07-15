import 'package:flutter/material.dart';

class OnboardingProfileStep extends StatelessWidget {
  final TextEditingController displayNameCtrl;
  final DateTime? birthDate;
  final VoidCallback onPickBirthDate;
  final String birthDateLabel;

  final Set<String> selectedSports;
  final void Function(String sport, bool selected) onSportToggle;

  const OnboardingProfileStep({
    super.key,
    required this.displayNameCtrl,
    required this.birthDate,
    required this.onPickBirthDate,
    required this.birthDateLabel,
    required this.selectedSports,
    required this.onSportToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu perfil', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text('Dinos quien eres.', style: t.bodyLarge),
          const SizedBox(height: 24),

          TextField(
            controller: displayNameCtrl,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: onPickBirthDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Birth date',
                border: OutlineInputBorder(),
              ),
              child: Text(birthDateLabel),
            ),
          ),

          const SizedBox(height: 24),

          Text('Deportes', style: t.titleMedium),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _sportChip(
                label: 'Tenis',
                icon: Icons.sports_tennis,
                selected: selectedSports.contains('Tenis'),
                onChanged: (v) => onSportToggle('Tenis', v),
              ),
              _sportChip(
                label: 'Correr',
                icon: Icons.directions_run,
                selected: selectedSports.contains('Correr'),
                onChanged: (v) => onSportToggle('Correr', v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sportChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    );
  }
}
