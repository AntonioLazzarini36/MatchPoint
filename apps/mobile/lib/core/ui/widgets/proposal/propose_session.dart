import 'package:match_point/core/analytics/analytics.dart';
import 'package:flutter/material.dart';

import '../../../location/location_result.dart';
import '../../location/location_search_screen.dart';
import 'map_point_picker.dart';
import 'tennis_club_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../features/onboarding/services/profile_service.dart';
import '../../../network/api.dart';
import '../../../../features/discovery/models/sport.dart';
import '../../../../features/matches/services/proposal_service.dart';
import 'week_calendar_picker.dart';
import 'time_slot_picker.dart';
import '../../../../features/onboarding/models/availability.dart';
import '../../../utils/slot_suggestions.dart';

/// Flujo unico para proponer una sesion, sea tenis o correr.
///
/// Antes habia dos caminos separados que ademas solo mandaban un mensaje
/// de texto al chat: nada que aceptar, sin estado, y se perdia scrolleando.
/// Ahora los dos crean una `Proposal` de verdad (POST
/// /matches/:matchId/proposals) que la otra persona puede aceptar o
/// rechazar, y que aparece en la pestaña de Quedadas.
///
/// Si se conoce el horario habitual de la otra persona
/// ([otherAvailability]) se enseña en los pasos de dia y hora, para no
/// proponer un hueco en el que esa persona no puede nunca. Nunca bloquea
/// nada: es lo que suele pasar, no su agenda.
///
/// El sitio es opcional a proposito: en tenis normalmente viene ya elegido
/// del mapa de clubes (`presetPlaceName` + coordenadas), y corriendo puede
/// no haberlo ("ya vemos donde").
///
/// Devuelve true si se llego a crear la propuesta.
class _PlaceChoice {
  /// null = "sin sitio concreto", explicito. No confundir con cancelar el
  /// flujo entero, que se expresa devolviendo null desde el bottom sheet.
  final LocationResult? location;
  const _PlaceChoice(this.location);
}

Future<bool> proposeSession(
  BuildContext context, {
  required String matchId,
  required Sport sport,
  String? presetPlaceName,
  double? presetPlaceLat,
  double? presetPlaceLng,
  WeeklyAvailability? otherAvailability,
  WeeklyAvailability? myAvailability,
  String? otherName,
}) async {
  String? placeName = presetPlaceName;
  double? placeLat = presetPlaceLat;
  double? placeLng = presetPlaceLng;

  // Con sitio ya elegido (tenis desde el mapa de clubes) no tiene sentido
  // volver a preguntarlo.
  if (presetPlaceName == null) {
    final choice = await showModalBottomSheet<_PlaceChoice>(
      context: context,
      builder: (_) => _PlaceSheet(sport: sport),
    );
    if (choice == null || !context.mounted) return false;
    placeName = choice.location?.displayName;
    placeLat = choice.location?.latitude;
    placeLng = choice.location?.longitude;
  }

  // Cruzar los dos horarios y ofrecer huecos concretos, antes de abrir un
  // calendario en blanco. Es el paso que convierte "creo que los sábados le
  // venian bien" en "sábado 30 a las 10:00" — y el dato ya estaba en los dos
  // perfiles, sólo que nadie lo cruzaba en el único momento en que decide
  // algo. Si no hay coincidencias (o alguno no ha rellenado su horario) esta
  // hoja no aparece y se va directo al calendario de siempre.
  final suggestions = suggestSlots(
    mine: myAvailability ?? WeeklyAvailability.empty,
    theirs: otherAvailability ?? WeeklyAvailability.empty,
  );

  DateTime? day;
  TimeOfDay? time;

  if (suggestions.isNotEmpty) {
    final picked = await showModalBottomSheet<SlotSuggestion>(
      context: context,
      builder: (_) => _SuggestionSheet(
        suggestions: suggestions,
        otherName: otherName,
      ),
    );
    if (!context.mounted) return false;
    if (picked != null) {
      day = picked.day;
      time = TimeOfDay(hour: picked.hour, minute: 0);
    }
    // `picked == null` no es cancelar: la hoja tiene su propio "elegir otro
    // día", que cierra sin elegir para caer en el calendario de abajo.
  }

  if (day == null) {
    day = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (_) => WeekCalendarPicker(
        otherAvailability: otherAvailability,
        otherName: otherName,
      ),
    );
    if (day == null || !context.mounted) return false;
  }

  // La hora se pregunta igual aunque venga sugerida: la sugerencia acierta el
  // día y la franja, pero "por la mañana" son seis horas y a alguien le puede
  // venir mejor a las 11 que a las 10. Llega ya puesta, así que confirmarla
  // es un toque.
  time = await pickTimeSlot(
    context,
    day: day,
    initial: time,
    otherAvailability: otherAvailability,
    otherName: otherName,
  );
  if (time == null || !context.mounted) return false;

  final scheduledAt = DateTime(
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  );

  final messenger = ScaffoldMessenger.of(context);
  try {
    Analytics.proposalCreated();
    await ProposalService(Api.client).create(
      matchId: matchId,
      sport: sport,
      scheduledAt: scheduledAt,
      placeName: placeName,
      placeLat: placeLat,
      placeLng: placeLng,
    );
    messenger.showSnackBar(const SnackBar(content: Text('Propuesta enviada')));
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
    return false;
  }
}

class _PlaceSheet extends StatefulWidget {
  final Sport sport;
  const _PlaceSheet({required this.sport});

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  /// Centro inicial del mapa: la ubicación del propio perfil, para no
  /// abrirlo en mitad del oceano. Se pide en segundo plano — si tarda o
  /// falla, el boton del mapa espera y el resto de opciones ya funcionan.
  LatLng? _myLocation;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final me = await ProfileService(Api.client).getMe();
      final profile = me.profile;
      if (!mounted) return;
      setState(() {
        if (profile != null && profile.hasLocation) {
          _myLocation = LatLng(profile.latitude!, profile.longitude!);
        }
        _loadingLocation = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickOnMap() async {
    final center = _myLocation;
    if (center == null) return;
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(
        builder: (_) => MapPointPicker(
          initialCenter: center,
          title: widget.sport == Sport.running
              ? 'Punto de encuentro'
              : '¿Dónde jugáis?',
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(_PlaceChoice(result));
  }

  Future<void> _searchPlace() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (!mounted) return;
    Navigator.of(context).pop(_PlaceChoice(result));
  }

  /// Solo tenis: el buscador por nombre es un geocodificador de sitios y
  /// no encuentra pistas (feedback del usuario: "solo busca municipios").
  /// Los clubes salen de OpenStreetMap via Overpass, igual que el mapa de
  /// clubes de Matches.
  Future<void> _pickClub() async {
    final center = _myLocation;
    if (center == null) return;
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => TennisClubPicker(center: center)),
    );
    if (!mounted) return;
    if (result == null) return; // volvio atras sin elegir: no cierra la hoja
    Navigator.of(context).pop(_PlaceChoice(result));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isRunning = widget.sport == Sport.running;
    final canUseMap = _myLocation != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRunning ? '¿Punto de encuentro?' : '¿Dónde jugáis?',
              style: t.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              isRunning
                  ? 'Marca el sitio exacto en el mapa — mucho más útil que '
                        'decir sólo el municipio.'
                  : 'Elige un club de los que hay cerca, o marca el punto '
                        'exacto en el mapa.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 16),

            // En tenis lo primero es el club: es donde se juega de verdad,
            // y es justo lo que el buscador por nombre no sabe encontrar.
            // Corriendo no hay equivalente, asi que ahi manda el mapa: el
            // caso real es "en esta esquina del parque", que un buscador
            // de municipios no sabe expresar.
            if (!isRunning) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canUseMap ? _pickClub : null,
                  icon: _loadingLocation
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sports_tennis),
                  label: const Text('Elegir un club cerca'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: isRunning
                  ? FilledButton.icon(
                      onPressed: canUseMap ? _pickOnMap : null,
                      icon: _loadingLocation
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.map_outlined),
                      label: const Text('Marcar en el mapa'),
                    )
                  : OutlinedButton.icon(
                      onPressed: canUseMap ? _pickOnMap : null,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Marcar en el mapa'),
                    ),
            ),
            if (!_loadingLocation && !canUseMap) ...[
              const SizedBox(height: 6),
              Text(
                'Pon tu ubicación en Ajustes para poder elegir sitio en el '
                'mapa.',
                style: t.bodySmall,
              ),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _searchPlace,
                icon: const Icon(Icons.search),
                label: const Text('Buscar un sitio por nombre'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _PlaceChoice(null)),
                child: const Text('Proponer sin sitio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los huecos en los que coincidís, como primera opción al proponer.
class _SuggestionSheet extends StatelessWidget {
  final List<SlotSuggestion> suggestions;
  final String? otherName;

  const _SuggestionSheet({required this.suggestions, this.otherName});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cuándo quedáis?', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(
              otherName == null
                  ? 'Estos huecos os vienen bien a los dos.'
                  : 'Estos huecos os vienen bien a ti y a $otherName.',
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.label,
                              style: t.titleMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: scheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                // Cierra sin elegir, y el flujo sigue por el calendario. No
                // es cancelar: cancelar es el gesto de cerrar la hoja.
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Elegir otro día'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
