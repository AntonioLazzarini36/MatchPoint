import 'package:flutter/material.dart';

import 'package:match_point/core/ui/widgets/availability_picker.dart';
import 'package:match_point/core/utils/app_sports.dart';
import 'package:match_point/features/discovery/models/skill_level.dart';
import 'package:match_point/features/discovery/models/sport.dart';
import 'package:match_point/features/onboarding/models/availability.dart';

/// "Tu juego": nivel y cuándo sueles poder.
///
/// Son los dos únicos datos con los que la app empareja de verdad, así que
/// van juntos y solos en su propio paso. Antes estaban repartidos: el nivel
/// en un paso con años jugando / club / logros / ritmo / distancia, y el
/// horario enterrado al final de un paso de "preferencias" junto al rango de
/// edad y el filtro de género.
///
/// Lo que se fue de aquí y por qué: **credenciales** (años, club, logros) son
/// para lucirse, no para emparejar, y pedirlas antes de que alguien haya
/// visto un solo perfil es pedir esfuerzo a cambio de nada — se rellenan
/// desde Ajustes cuando ya hay motivo. **Rango de edad, radio y género** son
/// filtros con valores por defecto razonables que casi nadie toca, y que en
/// una app vacía sólo sirven para dejarla más vacía todavía.
class OnboardingPlayStep extends StatelessWidget {
  final Map<Sport, SkillLevel> skillLevels;
  final ValueChanged<Map<Sport, SkillLevel>> onSkillLevelsChanged;

  final WeeklyAvailability availability;
  final ValueChanged<WeeklyAvailability> onAvailabilityChanged;

  const OnboardingPlayStep({
    super.key,
    required this.skillLevels,
    required this.onSkillLevelsChanged,
    required this.availability,
    required this.onAvailabilityChanged,
  });

  void _setLevel(Sport sport, SkillLevel? level) {
    final next = Map<Sport, SkillLevel>.from(skillLevels);
    if (level == null) {
      next.remove(sport);
    } else {
      next[sport] = level;
    }
    onSkillLevelsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu partido', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Ayúdanos a encontrar tu rival perfecto.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 28),

          for (final sport in enabledSports) ...[
            if (enabledSports.length > 1) ...[
              Text(sport.label, style: t.titleMedium),
              const SizedBox(height: 8),
            ] else ...[
              Text('¿Cuál es tu nivel?', style: t.titleMedium),
              const SizedBox(height: 4),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in SkillLevel.values)
                  ChoiceChip(
                    label: Text(level.label),
                    selected: skillLevels[sport] == level,
                    // Volver a tocarlo lo desmarca: decirlo es opcional y sin
                    // esto no habría forma de retirar la respuesta.
                    onSelected: (selected) =>
                        _setLevel(sport, selected ? level : null),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          const Divider(),
          const SizedBox(height: 20),

          Text('¿Cuándo sueles poder jugar?', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Lo usamos para enseñarte antes quién coincide contigo.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          AvailabilityPicker(
            value: availability,
            onChanged: onAvailabilityChanged,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
