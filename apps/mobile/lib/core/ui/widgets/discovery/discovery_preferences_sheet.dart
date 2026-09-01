import 'package:flutter/material.dart';

import '../../../network/api.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/sport.dart';
import '../../../utils/app_sports.dart';
import '../../../utils/sport_words.dart';
import '../../../../features/onboarding/models/profile.dart';
import '../../../../features/onboarding/services/profile_service.dart';
import '../../../../core/network/connection_error.dart';
import '../../../../features/discovery/models/discover_filters.dart';
import '../../../../features/discovery/models/skill_level.dart';
import 'when_filter_sheet.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Filtros de Discovery (cuando, nivel, edad), compartidos
/// entre Ajustes y el boton de filtros de la propia pantalla de Discovery
/// - antes vivian solo dentro de `settings_screen.dart` como widget
/// privado, asi que el icono de filtros de Discovery no tenia nada que
/// abrir y era un `TODO` inerte.
///
/// Se guarda solo (no devuelve un resultado que el llamante tenga que
/// persistir): asi los dos sitios que lo abren no duplican la llamada al
/// backend ni pueden desincronizarse. Devuelve `true` si el usuario
/// guardo, para que el llamante recargue lo que corresponda.
/// Lo que devuelve la hoja: si hubo que recargar el feed, y con que filtros.
class DiscoveryPrefsResult {
  /// `true` si se guardo algo (preferencias del servidor o filtros locales).
  final bool saved;

  /// Los filtros de busqueda tal como quedaron.
  final DiscoverFilters filters;

  const DiscoveryPrefsResult({required this.saved, required this.filters});
}

/// La abre sólo Descubrir. Ajustes tenía su propia fila que llevaba aquí y
/// se quitó: para eso está el icono de filtros de la propia pantalla, y tener
/// los mismos filtros en dos sitios era una forma segura de que alguien los
/// cambiara donde no toca.
Future<DiscoveryPrefsResult> showDiscoveryPreferencesSheet(
  BuildContext context, {
  required Preferences? current,
  required List<Sport> mySports,
  DiscoverFilters filters = DiscoverFilters.none,
}) async {
  final result = await showModalBottomSheet<DiscoveryPrefsResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PreferencesSheet(
      current: current,
      mySports: mySports,
      filters: filters,
    ),
  );
  return result ?? DiscoveryPrefsResult(saved: false, filters: filters);
}

class _PreferencesSheet extends StatefulWidget {
  final Preferences? current;

  /// Deportes que el usuario juega. Se usan como valor por defecto cuando
  /// nunca ha tocado "deportes que te interesa ver": ya los eligio en el
  /// onboarding, no tiene sentido volver a preguntarselo.
  final List<Sport> mySports;

  /// Cuando puede jugar y contra que nivel. Vivian en una barra encima de la
  /// lista de Descubrir y se han traido aqui: la pantalla principal se leia
  /// como un panel de control (titulo + subtitulo + dos chips + resultados) y
  /// lo que tiene que hacer es enseñar gente. Siguen siendo los filtros que
  /// mas deciden, asi que van los **primeros** de esta hoja.
  final DiscoverFilters filters;

  const _PreferencesSheet({
    required this.current,
    required this.mySports,
    required this.filters,
  });

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late RangeValues _ageRange;
  late Set<Sport> _sportsWanted;
  late DiscoverFilters _filters;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = widget.current;
    _ageRange = RangeValues(
      (prefs?.ageMin ?? 18).toDouble(),
      (prefs?.ageMax ?? 60).toDouble(),
    );
    final wanted = prefs?.sportsWanted ?? const <Sport>[];
    // Se recorta a los propios por si quedo guardado un deporte que el
    // usuario ha dejado de practicar desde entonces.
    final shared = wanted.where(widget.mySports.contains).toSet();
    _sportsWanted = shared.isEmpty ? widget.mySports.toSet() : shared;
    _filters = widget.filters;
  }

  Future<void> _save() async {
    if (_sportsWanted.isEmpty) {
      setState(
        () => _error = S.current.chooseAtLeastOneSport,
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ProfileService(Api.client).updatePreferences(
        ageMin: _ageRange.start.round(),
        ageMax: _ageRange.end.round(),
        sportsWanted: _sportsWanted.toList(),
        // Se manda el que ya hubiera guardado, sin tocarlo: este parametro
        // es `required` y omitirlo lo borraria. El filtro salio de la
        // interfaz (ver arriba), no del backend.
        genderPreference: widget.current?.genderPreference,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(DiscoveryPrefsResult(saved: true, filters: _filters));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(
          e,
          fallback: S.current.couldNotSaveFilters,
        );
      });
    }
  }

  Future<void> _pickLevel() async {
    final picked = await showModalBottomSheet<_LevelChoice>(
      context: context,
      builder: (_) => _LevelSheet(current: _filters.level),
    );
    if (picked == null) return;
    setState(() {
      _filters = picked.level == null
          ? _filters.copyWith(clearLevel: true)
          : _filters.copyWith(level: picked.level);
    });
  }

  void _toggleSport(Sport sport, bool selected) {
    setState(() {
      if (selected) {
        _sportsWanted.add(sport);
      } else {
        _sportsWanted.remove(sport);
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Scroll + hueco para gestos: en pantallas pequenas las tres
        // secciones no entran de una.
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.current.filters, style: context.textStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                S.current.filtersDecideWhoWeShow,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // Los dos que de verdad deciden con quien acabas jugando, y por
              // eso van los primeros.
              ...[
                _FilterRow(
                  icon: Icons.schedule,
                  label: S.current.whenICanPlay,
                  value: _filters.when.isEmpty
                      ? S.current.anyTime
                      : (_filters.when.count <= 2
                            ? _filters.when.slotLabels.join(' · ')
                            : '${_filters.when.count} franjas'),
                  active: _filters.when.isNotEmpty,
                  onTap: () async {
                    final picked = await showWhenFilterSheet(
                      context,
                      current: _filters.when,
                    );
                    if (picked == null) return;
                    setState(() => _filters = _filters.copyWith(when: picked));
                  },
                ),
                _FilterRow(
                  icon: Icons.workspace_premium_outlined,
                  label: S.current.level,
                  value: _filters.level?.label ?? S.current.anyLevel,
                  active: _filters.level != null,
                  onTap: _pickLevel,
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
              ],

              Text(S.current.ageRange, style: context.textStyles.titleSmall),
              Text(
                S.current.ageRangeValue(_ageRange.start.round(), _ageRange.end.round()),
                style: context.textStyles.bodyMedium,
              ),
              RangeSlider(
                values: _ageRange,
                min: 18,
                max: 100,
                divisions: 82,
                labels: RangeLabels(
                  '${_ageRange.start.round()}',
                  '${_ageRange.end.round()}',
                ),
                onChanged: (v) => setState(() => _ageRange = v),
              ),
              // El selector de deporte sólo aparece si hay más de uno que
              // elegir: en una app de tenis es un control con una sola
              // opción, que es peor que no tenerlo.
              if (!isSingleSportApp) ...[
                const SizedBox(height: 12),
                Text(
                  S.current.sportsYouWantToSee,
                  style: context.textStyles.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Sólo tus deportes: esto acota lo que ves, no lo
                    // amplia. Ofrecer uno que no juegas sería ofrecer
                    // matches que luego no se pueden convertir en una
                    // quedada, porque proponer exige que ambos lo practiquen.
                    for (final sport in widget.mySports)
                      FilterChip(
                        label: Text(sport.label),
                        avatar: Icon(sportIcon(sport), size: 18),
                        selected: _sportsWanted.contains(sport),
                        onSelected: (v) => _toggleSport(sport, v),
                        showCheckmark: false,
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(S.current.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila de filtro: nombre a la izquierda, valor actual a la derecha.
/// Se pinta en color cuando hay algo puesto, para que al abrir la hoja se vea
/// de un vistazo que esta filtrando y que no.
class _FilterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  const _FilterRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.textStyles.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: active ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.outline),
          ],
        ),
      ),
    );
  }
}

/// Envoltorio para distinguir "eligio Cualquiera" (que quita el filtro) de
/// "cerro sin tocar nada" — con un `SkillLevel?` pelado las dos llegan null.
class _LevelChoice {
  final SkillLevel? level;
  const _LevelChoice(this.level);
}

class _LevelSheet extends StatelessWidget {
  final SkillLevel? current;
  const _LevelSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(S.current.level, style: context.textStyles.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              S.current.levelSheetHint,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          _LevelOption(
            label: S.current.anyLevel,
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
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: context.colors.primary)
          : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
