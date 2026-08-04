import 'package:flutter/material.dart';

import 'package:match_point/features/onboarding/models/gender.dart';

/// Antes era solo el paso de "objetivo" (3 tarjetas, guardado como `bio`).
/// Ahora ademas es donde se setean las preferencias reales de a quien
/// mostrar en Discovery mas adelante (edad, genero) - el objetivo sigue
/// existiendo (primera seccion), pero ya no es lo unico de este paso.
/// `distanceKm` sigue viviendo en el paso de ubicacion (tiene mas sentido
/// ahi, ligado al mapa) - no se duplica aqui. Los deportes que quiere ver
/// no se preguntan aqui: por defecto son los mismos que ya eligio como
/// propios (ver `_effectiveSportsWanted` en onboarding_profile_screen.dart)
/// - cambiarlo es cosa de Settings, no del onboarding.
class OnboardingPreferencesStep extends StatelessWidget {
  final String goal;
  final ValueChanged<String> onGoalChanged;

  final RangeValues ageRange;
  final ValueChanged<RangeValues> onAgeRangeChanged;

  /// null = "Cualquiera". Se manda siempre al backend (incluso como null
  /// explícito), así que no hace falta un centinela tipo '' para
  /// distinguirlo de "no lo toques" — ver `updatePreferences` en
  /// profile_service.dart.
  final Gender? genderPreference;
  final ValueChanged<Gender?> onGenderPreferenceChanged;

  const OnboardingPreferencesStep({
    super.key,
    required this.goal,
    required this.onGoalChanged,
    required this.ageRange,
    required this.onAgeRangeChanged,
    required this.genderPreference,
    required this.onGenderPreferenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Que buscas', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Esto ayuda a mostrarte a la gente que encaja con lo que '
            'buscas, y a ti a quien encaja con ellos.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 20),

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
            icon: Icons.all_inclusive,
            selected: goal == 'Ambos',
            onTap: () => onGoalChanged('Ambos'),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          Text('Rango de edad', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A quien quieres ver en Discovery, por edad.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${ageRange.start.round()} - ${ageRange.end.round()} anos',
            style: t.titleLarge,
          ),
          RangeSlider(
            values: ageRange,
            min: 18,
            max: 100,
            divisions: 82,
            labels: RangeLabels(
              '${ageRange.start.round()}',
              '${ageRange.end.round()}',
            ),
            onChanged: onAgeRangeChanged,
          ),

          const Divider(),
          const SizedBox(height: 20),

          Text('Quiero ver', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Quien no haya dicho su género te seguirá apareciendo.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Cualquiera'),
                selected: genderPreference == null,
                onSelected: (_) => onGenderPreferenceChanged(null),
              ),
              for (final option in Gender.values)
                ChoiceChip(
                  label: Text(option.pluralLabel),
                  selected: genderPreference == option,
                  onSelected: (_) => onGenderPreferenceChanged(option),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                  color: selected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
