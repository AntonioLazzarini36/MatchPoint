import 'package:flutter/material.dart';

import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/features/discovery/models/discover_filters.dart';
import 'package:match_point/features/discovery/models/skill_level.dart';

import 'when_filter_sheet.dart';

/// La barra que convierte "Descubrir" en una búsqueda.
///
/// Va **encima** de los resultados y no detrás de un icono de embudo, que es
/// donde vivía antes: el filtro de "cuándo" no es un ajuste fino que se toca
/// una vez, es la pregunta. Escondiéndolo, la pantalla vuelve a ser un mazo
/// de caras con un botón de opciones al lado.
class DiscoveryFilterBar extends StatelessWidget {
  final DiscoverFilters filters;
  final ValueChanged<DiscoverFilters> onChanged;

  const DiscoveryFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  Future<void> _editWhen(BuildContext context) async {
    final picked = await showWhenFilterSheet(context, current: filters.when);
    if (picked == null) return;
    onChanged(filters.copyWith(when: picked));
  }

  Future<void> _editLevel(BuildContext context) async {
    final picked = await showModalBottomSheet<_LevelChoice>(
      context: context,
      builder: (_) => _LevelSheet(current: filters.level),
    );
    if (picked == null) return;
    onChanged(
      picked.level == null
          ? filters.copyWith(clearLevel: true)
          : filters.copyWith(level: picked.level),
    );
  }

  @override
  Widget build(BuildContext context) {
    final when = filters.when;
    // Con pocas franjas se dicen (es más útil que un número); con muchas, el
    // texto no cabe y el número sí informa.
    final whenLabel = when.isEmpty
        ? 'Cuándo puedo jugar'
        : (when.count <= 2
              ? when.slotLabels.join(' · ')
              : '${when.count} franjas');

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            icon: Icons.schedule,
            label: whenLabel,
            active: when.isNotEmpty,
            onTap: () => _editWhen(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.workspace_premium_outlined,
            label: filters.level?.label ?? 'Nivel',
            active: filters.level != null,
            onTap: () => _editLevel(context),
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(width: 8),
            _Chip(
              icon: Icons.close,
              label: 'Quitar filtros',
              active: false,
              onTap: () => onChanged(DiscoverFilters.none),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = active ? colors.onPrimary : colors.onSurface;

    return Material(
      color: active ? colors.primary : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textStyles.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Envoltorio para poder distinguir "eligió Cualquiera" (que borra el
/// filtro) de "cerró la hoja sin tocar nada" — con un `SkillLevel?` pelado
/// las dos cosas llegan como `null`.
class _LevelChoice {
  final SkillLevel? level;
  const _LevelChoice(this.level);
}

class _LevelSheet extends StatelessWidget {
  final SkillLevel? current;
  const _LevelSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Nivel', style: t.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Un partido igualado es mejor partido. Esto es el nivel que '
              'cada uno dice tener, no un ranking.',
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _LevelOption(
            label: 'Cualquiera',
            selected: current == null,
            onTap: () => Navigator.of(context).pop(const _LevelChoice(null)),
          ),
          for (final level in SkillLevel.values)
            _LevelOption(
              label: level.label,
              selected: current == level,
              onTap: () => Navigator.of(context).pop(_LevelChoice(level)),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LevelOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LevelOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: colors.primary)
          : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
