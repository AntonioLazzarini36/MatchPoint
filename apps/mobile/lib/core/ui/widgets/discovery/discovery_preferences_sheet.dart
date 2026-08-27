import 'package:flutter/material.dart';

import '../../../network/api.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/sport.dart';
import '../../../utils/app_sports.dart';
import '../../../utils/sport_words.dart';
import '../../../../features/onboarding/models/gender.dart';
import '../../../../features/onboarding/models/profile.dart';
import '../../../../features/onboarding/services/profile_service.dart';
import '../../../../core/network/connection_error.dart';

/// Filtros de Discovery (edad, deportes buscados, genero), compartidos
/// entre Ajustes y el boton de filtros de la propia pantalla de Discovery
/// - antes vivian solo dentro de `settings_screen.dart` como widget
/// privado, asi que el icono de filtros de Discovery no tenia nada que
/// abrir y era un `TODO` inerte.
///
/// Se guarda solo (no devuelve un resultado que el llamante tenga que
/// persistir): asi los dos sitios que lo abren no duplican la llamada al
/// backend ni pueden desincronizarse. Devuelve `true` si el usuario
/// guardo, para que el llamante recargue lo que corresponda.
Future<bool> showDiscoveryPreferencesSheet(
  BuildContext context, {
  required Preferences? current,
  required List<Sport> mySports,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PreferencesSheet(current: current, mySports: mySports),
  );
  return saved ?? false;
}

class _PreferencesSheet extends StatefulWidget {
  final Preferences? current;

  /// Deportes que el usuario juega. Se usan como valor por defecto cuando
  /// nunca ha tocado "deportes que te interesa ver": ya los eligio en el
  /// onboarding, no tiene sentido volver a preguntarselo.
  final List<Sport> mySports;

  const _PreferencesSheet({required this.current, required this.mySports});

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late RangeValues _ageRange;
  late Set<Sport> _sportsWanted;
  late Gender? _genderPreference;

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
    _genderPreference = prefs?.genderPreference;
  }

  Future<void> _save() async {
    if (_sportsWanted.isEmpty) {
      setState(
        () => _error = 'Elige al menos un deporte para poder ver perfiles',
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
        genderPreference: _genderPreference,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(
          e,
          fallback: 'No se han podido guardar los filtros.',
        );
      });
    }
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
              Text(
                'Filtros de Descubrir',
                style: context.textStyles.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Deciden a quién te mostramos. El radio de distancia se '
                'cambia en Ajustes, junto a tu ubicación.',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('Rango de edad', style: context.textStyles.titleSmall),
              Text(
                '${_ageRange.start.round()} - ${_ageRange.end.round()} años',
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
                  'Deportes que quieres ver',
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
              const SizedBox(height: 16),
              Text('Quiero ver', style: context.textStyles.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('Cualquiera'),
                    selected: _genderPreference == null,
                    onSelected: (_) => setState(() => _genderPreference = null),
                  ),
                  for (final gender in Gender.values)
                    ChoiceChip(
                      label: Text(gender.pluralLabel),
                      selected: _genderPreference == gender,
                      onSelected: (_) =>
                          setState(() => _genderPreference = gender),
                    ),
                ],
              ),
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
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
