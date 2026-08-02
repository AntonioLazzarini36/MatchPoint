import 'package:flutter/material.dart';

import 'package:match_point/features/discovery/models/skill_level.dart';
import 'package:match_point/features/discovery/models/sport.dart';

/// Nivel por deporte + credenciales — para que la otra persona pueda
/// pensar "che, este juega a mi nivel" antes de organizar nada (ver
/// status.md, "Reposicionamiento de producto"). Todo opcional a
/// propósito: no bloquea el "Siguiente" del wizard.
class OnboardingSkillStep extends StatelessWidget {
  final List<Sport> sports;
  final Map<Sport, SkillLevel> skillLevels;
  final ValueChanged<Map<Sport, SkillLevel>> onSkillLevelsChanged;
  final int? yearsPlaying;
  final ValueChanged<int?> onYearsPlayingChanged;
  final String club;
  final ValueChanged<String> onClubChanged;
  final List<String> achievements;
  final ValueChanged<List<String>> onAchievementsChanged;

  const OnboardingSkillStep({
    super.key,
    required this.sports,
    required this.skillLevels,
    required this.onSkillLevelsChanged,
    required this.yearsPlaying,
    required this.onYearsPlayingChanged,
    required this.club,
    required this.onClubChanged,
    required this.achievements,
    required this.onAchievementsChanged,
  });

  void _setLevel(Sport sport, SkillLevel level) {
    final updated = Map<Sport, SkillLevel>.from(skillLevels);
    updated[sport] = level;
    onSkillLevelsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu nivel', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Para que quien vea tu perfil sepa si juega a tu nivel antes '
            'de organizar nada. Todo esto es opcional, pero ayuda mucho.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),
          for (final sport in sports) ...[
            Text(sport.label, style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SkillLevel.values.map((level) {
                return ChoiceChip(
                  label: Text(level.label),
                  selected: skillLevels[sport] == level,
                  onSelected: (_) => _setLevel(sport, level),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
          const Divider(),
          const SizedBox(height: 16),
          Text('Credenciales (opcional)', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Años jugando, tu club, torneos o logros — lo que quieras que '
            'se vea en tu perfil.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('years-$yearsPlaying'),
            initialValue: yearsPlaying?.toString() ?? '',
            decoration: const InputDecoration(labelText: 'Años jugando'),
            keyboardType: TextInputType.number,
            onChanged: (v) => onYearsPlayingChanged(int.tryParse(v)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: club,
            decoration: const InputDecoration(labelText: 'Club'),
            onChanged: onClubChanged,
          ),
          const SizedBox(height: 16),
          _AchievementsEditor(
            achievements: achievements,
            onChanged: onAchievementsChanged,
          ),
        ],
      ),
    );
  }
}

class _AchievementsEditor extends StatefulWidget {
  final List<String> achievements;
  final ValueChanged<List<String>> onChanged;

  const _AchievementsEditor({
    required this.achievements,
    required this.onChanged,
  });

  @override
  State<_AchievementsEditor> createState() => _AchievementsEditorState();
}

class _AchievementsEditorState extends State<_AchievementsEditor> {
  final _ctrl = TextEditingController();

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onChanged([...widget.achievements, text]);
    _ctrl.clear();
  }

  void _remove(int index) {
    final updated = [...widget.achievements]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Torneos / logros', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Ej. Campeón provincial 2024',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: _add),
          ],
        ),
        if (widget.achievements.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.achievements.length; i++)
                Chip(
                  label: Text(widget.achievements[i]),
                  onDeleted: () => _remove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
