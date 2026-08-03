import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:match_point/core/utils/pace_format.dart';
import 'package:match_point/features/discovery/models/skill_level.dart';
import 'package:match_point/features/discovery/models/sport.dart';

/// Nivel por deporte + credenciales — para que la otra persona pueda
/// pensar "che, este juega a mi nivel" antes de organizar nada (ver
/// status.md, "Reposicionamiento de producto"). Las credenciales que se
/// muestran dependen de qué deportes elegiste en el paso anterior:
/// años jugando/club para tenis, ritmo/distancia media para correr —
/// los logros son compartidos, sea cual sea el deporte. Todo el paso es
/// opcional — eso lo comunica el botón "Saltar" de
/// `OnboardingProfileScreen`, no un texto acá.
///
/// `StatefulWidget` con `TextEditingController`s a propósito, no
/// `TextFormField(initialValue: ..., key: ValueKey('algo-$valor'))`
/// como tenía antes: esa key cambiaba con cada tecla (porque el valor
/// que forma parte de la key es justo el que se está escribiendo), así
/// que Flutter destruía y recreaba el campo en cada pulsación — perdía
/// el foco a mitad de escribir y saltaba al siguiente campo (bug
/// reportado en vivo, 2026-08-02). Con un controller creado una sola
/// vez en `initState`, el campo sigue siendo el mismo widget mientras
/// se escribe.
class OnboardingSkillStep extends StatefulWidget {
  final List<Sport> sports;
  final Map<Sport, SkillLevel> skillLevels;
  final ValueChanged<Map<Sport, SkillLevel>> onSkillLevelsChanged;
  final int? yearsPlaying;
  final ValueChanged<int?> onYearsPlayingChanged;
  final String club;
  final ValueChanged<String> onClubChanged;
  final double? avgPaceMinPerKm;
  final ValueChanged<double?> onAvgPaceMinPerKmChanged;
  final double? avgDistanceKm;
  final ValueChanged<double?> onAvgDistanceKmChanged;
  final List<String> achievements;
  final ValueChanged<List<String>> onAchievementsChanged;
  final VoidCallback? onFieldSubmitted;

  const OnboardingSkillStep({
    super.key,
    required this.sports,
    required this.skillLevels,
    required this.onSkillLevelsChanged,
    required this.yearsPlaying,
    required this.onYearsPlayingChanged,
    required this.club,
    required this.onClubChanged,
    required this.avgPaceMinPerKm,
    required this.onAvgPaceMinPerKmChanged,
    required this.avgDistanceKm,
    required this.onAvgDistanceKmChanged,
    required this.achievements,
    required this.onAchievementsChanged,
    this.onFieldSubmitted,
  });

  @override
  State<OnboardingSkillStep> createState() => _OnboardingSkillStepState();
}

class _OnboardingSkillStepState extends State<OnboardingSkillStep> {
  late final TextEditingController _yearsCtrl;
  late final TextEditingController _clubCtrl;
  late final TextEditingController _paceCtrl;
  late final TextEditingController _distanceCtrl;

  @override
  void initState() {
    super.initState();
    _yearsCtrl = TextEditingController(
      text: widget.yearsPlaying?.toString() ?? '',
    );
    _clubCtrl = TextEditingController(text: widget.club);
    _paceCtrl = TextEditingController(
      text: formatPaceMinPerKm(widget.avgPaceMinPerKm),
    );
    _distanceCtrl = TextEditingController(
      text: widget.avgDistanceKm?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _yearsCtrl.dispose();
    _clubCtrl.dispose();
    _paceCtrl.dispose();
    _distanceCtrl.dispose();
    super.dispose();
  }

  void _setLevel(Sport sport, SkillLevel level) {
    final updated = Map<Sport, SkillLevel>.from(widget.skillLevels);
    updated[sport] = level;
    widget.onSkillLevelsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final playsTennis = widget.sports.contains(Sport.tennis);
    final playsRunning = widget.sports.contains(Sport.running);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu nivel', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Para que quien vea tu perfil sepa si juega a tu nivel antes '
            'de organizar nada.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),
          for (final sport in widget.sports) ...[
            Text(sport.label, style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SkillLevel.values.map((level) {
                return ChoiceChip(
                  label: Text(level.label),
                  selected: widget.skillLevels[sport] == level,
                  onSelected: (_) => _setLevel(sport, level),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
          const Divider(),
          const SizedBox(height: 16),
          Text('Credenciales', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Lo que quieras que se vea en tu perfil para dar confianza.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          if (playsTennis) ...[
            TextFormField(
              controller: _yearsCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
              decoration: const InputDecoration(labelText: 'Años jugando al tenis'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (v) => widget.onYearsPlayingChanged(int.tryParse(v)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clubCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
              decoration: const InputDecoration(labelText: 'Club'),
              onChanged: widget.onClubChanged,
            ),
            const SizedBox(height: 12),
          ],
          if (playsRunning) ...[
            TextFormField(
              controller: _paceCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
              decoration: const InputDecoration(
                labelText: 'Ritmo medio (min:seg / km)',
                hintText: 'Ej. 4:30',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (v) =>
                  widget.onAvgPaceMinPerKmChanged(parsePaceMinPerKm(v)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _distanceCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
              decoration: const InputDecoration(
                labelText: 'Distancia media (km)',
                hintText: 'Ej. 10',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (v) =>
                  widget.onAvgDistanceKmChanged(double.tryParse(v)),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          _AchievementsEditor(
            achievements: widget.achievements,
            onChanged: widget.onAchievementsChanged,
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
  String? _error;

  static const _maxAchievements = 10;
  static const _maxLength = 80;

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > _maxLength) {
      setState(() => _error = 'Máximo $_maxLength caracteres por logro');
      return;
    }
    if (widget.achievements.length >= _maxAchievements) {
      setState(() => _error = 'Máximo $_maxAchievements logros');
      return;
    }
    setState(() => _error = null);
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
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
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
