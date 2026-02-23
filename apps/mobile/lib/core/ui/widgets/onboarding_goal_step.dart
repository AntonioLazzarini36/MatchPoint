import 'package:flutter/material.dart';

class OnboardingGoalStep extends StatelessWidget {
  final String goal;
  final ValueChanged<String> onGoalChanged;

  const OnboardingGoalStep({
    super.key,
    required this.goal,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cuál es tu objetivo?', style: t.headlineMedium),
          const SizedBox(height: 12),

          _optionCard(
            context,
            title: 'Jugar por nivel',
            subtitle: 'Busco mejorar y competir',
            icon: Icons.trending_up,
            selected: goal == 'Jugar por nivel',
            onTap: () => onGoalChanged('Jugar por nivel'),
          ),
          _optionCard(
            context,
            title: 'Conocer gente',
            subtitle: 'Busco socializar y divertirme',
            icon: Icons.people,
            selected: goal == 'Conocer gente',
            onTap: () => onGoalChanged('Conocer gente'),
          ),
          _optionCard(
            context,
            title: 'Ambos',
            subtitle: 'Un poco de todo',
            icon: Icons.favorite,
            selected: goal == 'Ambos',
            onTap: () => onGoalChanged('Ambos'),
          ),
        ],
      ),
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: selected ? scheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}