import 'package:flutter/material.dart';

import 'package:match_point/features/onboarding/models/gender.dart';

class OnboardingProfileStep extends StatelessWidget {
  final TextEditingController displayNameCtrl;
  final DateTime? birthDate;
  final VoidCallback onPickBirthDate;
  final String birthDateLabel;

  /// null = "prefiero no decirlo", que es una respuesta válida y no
  /// bloquea el paso. Se pregunta aquí (y no en el paso de preferencias)
  /// porque es parte de quién eres, no de a quién buscas.
  final Gender? gender;
  final ValueChanged<Gender?> onGenderChanged;

  final Set<String> selectedSports;
  final void Function(String sport, bool selected) onSportToggle;
  final VoidCallback? onNameSubmitted;

  const OnboardingProfileStep({
    super.key,
    required this.displayNameCtrl,
    required this.birthDate,
    required this.onPickBirthDate,
    required this.birthDateLabel,
    required this.gender,
    required this.onGenderChanged,
    required this.selectedSports,
    required this.onSportToggle,
    this.onNameSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu perfil', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Esto es lo que va a ver el resto de la gente en tu perfil.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: displayNameCtrl,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onNameSubmitted?.call(),
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

          Text('Género', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Opcional. Ayuda a quien filtra por esto a encontrarte — y a '
            'que a ti no te aparezca quien no buscas.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in Gender.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: gender == option,
                  // Volver a tocar el que ya está elegido lo deselecciona:
                  // es la única forma de volver a "prefiero no decirlo"
                  // sin añadir un cuarto chip que diga eso mismo.
                  onSelected: (selected) =>
                      onGenderChanged(selected ? option : null),
                ),
            ],
          ),

          const SizedBox(height: 28),

          Text('¿A qué deporte juegas?', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Elege uno o los dos — esto decide a quién ves en Discovery y '
            'quién te ve a ti.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _SportCard(
                  label: 'Tenis',
                  icon: Icons.sports_tennis,
                  selected: selectedSports.contains('Tenis'),
                  onTap: () => onSportToggle(
                    'Tenis',
                    !selectedSports.contains('Tenis'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SportCard(
                  label: 'Correr',
                  icon: Icons.directions_run,
                  selected: selectedSports.contains('Correr'),
                  onTap: () => onSportToggle(
                    'Correr',
                    !selectedSports.contains('Correr'),
                  ),
                ),
              ),
            ],
          ),
          if (selectedSports.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Elige al menos un deporte para continuar.',
              style: t.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta grande de sí/no por deporte — a propósito mucho más notoria
/// que un `FilterChip` chico: color de fondo + borde + check cuando está
/// seleccionado, en vez de solo un cambio sutil de color, porque en la
/// versión anterior no quedaba claro cuál estaba elegido (feedback del
/// usuario, 2026-08-02).
class _SportCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SportCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  if (selected)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: t.titleSmall?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
