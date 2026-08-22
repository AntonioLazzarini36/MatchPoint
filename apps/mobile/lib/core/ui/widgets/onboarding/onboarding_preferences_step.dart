import 'package:flutter/material.dart';

import 'package:match_point/core/ui/widgets/availability_picker.dart';
import 'package:match_point/features/onboarding/models/availability.dart';
import 'package:match_point/features/onboarding/models/gender.dart';
import 'package:match_point/features/onboarding/models/intention.dart';

/// Antes la primera seccion era un "objetivo" de 3 tarjetas cuya frase se
/// guardaba **como la bio**: el resultado era que en toda la app solo habia
/// tres descripciones posibles y todos los perfiles se leian igual. Ahora esa
/// seccion es la **intencion**, un campo propio y estructurado (ver
/// `intention.dart`), y la descripcion se escribe a mano en el paso de
/// perfil. Ademas aqui se setean las preferencias de a quien mostrar en
/// Discovery (edad, genero).
/// `distanceKm` sigue viviendo en el paso de ubicacion (tiene mas sentido
/// ahi, ligado al mapa) - no se duplica aqui. Los deportes que quiere ver
/// no se preguntan aqui: por defecto son los mismos que ya eligio como
/// propios (ver `_effectiveSportsWanted` en onboarding_profile_screen.dart)
/// - cambiarlo es cosa de Settings, no del onboarding.
class OnboardingPreferencesStep extends StatelessWidget {
  /// null = todavia no ha elegido. No bloquea avanzar: decirlo es opcional.
  final Intention? intention;
  final ValueChanged<Intention?> onIntentionChanged;

  /// Cuando puedes jugar. Va en este paso y no en el de perfil porque
  /// responde a la misma pregunta que la intencion: como juegas, no quien
  /// eres. Y es lo que mas decide si dos personas acaban coincidiendo.
  final WeeklyAvailability availability;
  final ValueChanged<WeeklyAvailability> onAvailabilityChanged;

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
    required this.intention,
    required this.onIntentionChanged,
    required this.availability,
    required this.onAvailabilityChanged,
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
          Text('A que vienes', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Aparece en tu perfil. Es lo que hace que alguien sepa, antes de '
            'escribirte, si busca lo mismo que tu.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 20),

          for (final option in Intention.values)
            _optionCard(
              context,
              title: option.label,
              subtitle: option.description,
              icon: option.icon,
              selected: intention == option,
              // Volver a tocar la elegida la desmarca: decirlo es opcional y
              // sin esto no habria forma de retirar la respuesta.
              onTap: () =>
                  onIntentionChanged(intention == option ? null : option),
            ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          Text('Cuando sueles tener libre', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'No hace falta que sea exacto. Lo vera quien quiera proponerte '
            'algo, para no elegir un hueco en el que nunca puedes.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          AvailabilityPicker(
            value: availability,
            onChanged: onAvailabilityChanged,
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
