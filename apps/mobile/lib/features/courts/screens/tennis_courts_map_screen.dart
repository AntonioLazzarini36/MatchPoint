import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/network/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../matches/models/match_item.dart';
import '../../matches/services/matches_service.dart';
import '../../onboarding/services/profile_service.dart';
import '../models/tennis_club.dart';
import '../services/overpass_service.dart';
import '../../../core/ui/widgets/proposal/name_place_dialog.dart';
import '../../../core/ui/widgets/proposal/propose_session.dart';
import '../../discovery/models/sport.dart';

/// Tennis clubs near a point, real OpenStreetMap data — see one on the
/// map, tap it, and propose it (with a date/time) to whichever match you
/// want by sending a message into that match's chat. Deliberately not
/// more than that yet: no booking/availability system, no dedicated
/// "proposal" backend concept — just a starting point per the "poco a
/// poco" ask, built on infrastructure that already exists (chat messages).
/// "Se lo propones sin saber si hay pista libre a esa hora" is the
/// explicit, current scope — checking real availability is a separate,
/// bigger feature (issue #18).
class TennisCourtsMapScreen extends StatefulWidget {
  const TennisCourtsMapScreen({super.key});

  @override
  State<TennisCourtsMapScreen> createState() => _TennisCourtsMapScreenState();
}

class _TennisCourtsMapScreenState extends State<TennisCourtsMapScreen> {
  // Fallback only for accounts that haven't set a location yet (see
  // feat/manual-location) — the real default is the user's own profile
  // location, loaded in initState.
  static const _fallbackCenter = LatLng(40.4168, -3.7038);

  final _mapController = MapController();
  final _overpass = OverpassService();
  final _profileService = ProfileService(Api.client);
  final _searchCtrl = TextEditingController();

  LatLng _center = _fallbackCenter;
  List<TennisClub> _clubs = [];
  bool _loadingClubs = false;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCenter();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCenter() async {
    try {
      final me = await _profileService.getMe();
      final profile = me.profile;
      if (profile != null && profile.hasLocation) {
        _center = LatLng(profile.latitude!, profile.longitude!);
      }
    } catch (_) {
      // Sin perfil/ubicación todavía -> se queda con el fallback, sin
      // bloquear la pantalla por esto.
    }
    if (!mounted) return;
    _mapController.move(_center, 13);
    await _loadClubs(_center);
  }

  Future<void> _loadClubs(LatLng center) async {
    setState(() {
      _loadingClubs = true;
      _error = null;
    });
    try {
      final clubs = await _overpass.nearbyClubs(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _loadingClubs = false;
      });
    } catch (e) {
      if (!mounted) return;
      // El detalle tecnico ("TimeoutException after 0:00:20...") no le
      // dice nada a nadie y ocupaba media pantalla en rojo; queda en la
      // consola, que es donde sirve para algo. Overpass es el servicio
      // publico y gratuito de OSM, lo comparte todo el mundo y se satura
      // a ratos: no es un fallo de la app ni algo que el usuario haya
      // hecho mal, asi que tampoco merece tratamiento de error grave.
      debugPrint('Overpass fallo: $e');
      setState(() {
        _error = 'El servicio de mapas esta saturado. Reintenta en unos '
            'segundos.';
        _loadingClubs = false;
      });
    }
  }

  Future<void> _searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _searching = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: {'q': trimmed, 'format': 'jsonv2', 'limit': '1'});
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'MatchPointApp/1.0 (dev)'},
      );
      final results = jsonDecode(res.body) as List<dynamic>;
      if (results.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sitio no encontrado')));
        return;
      }

      final first = results.first as Map<String, dynamic>;
      final lat = double.parse(first['lat'] as String);
      final lon = double.parse(first['lon'] as String);
      final newCenter = LatLng(lat, lon);

      if (!mounted) return;
      setState(() => _center = newCenter);
      _mapController.move(newCenter, 13);
      await _loadClubs(newCenter);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo buscar: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _openClubSheet(TennisClub club) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => _ClubSheet(
        club: club,
        onProposeMatch: () {
          Navigator.of(sheetContext).pop();
          _proposeClub(club);
        },
      ),
    );
  }

  /// Desde el mapa el sitio ya está elegido (el club), así que se salta
  /// el paso de "¿dónde?" y solo queda a quién y cuándo. La propuesta que
  /// se crea es la misma `Proposal` que desde el chat — antes esto
  /// mandaba un mensaje de texto suelto que no se podía aceptar.
  Future<void> _proposeClub(TennisClub club) async {
    final matchesService = MatchesService(Api.client);
    List<MatchItem> matches;
    try {
      matches = await matchesService.fetchMatches();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudieron cargar tus matches: $e')));
      return;
    }

    if (!mounted) return;

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todavía no tienes ningún match')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<MatchItem>(
      context: context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '¿A quién le proponés ${club.name}?',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final m in matches)
            ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    (m.otherUser.profile?.photos.isNotEmpty ?? false)
                    ? NetworkImage(m.otherUser.profile!.photos.first)
                    : null,
                child: (m.otherUser.profile?.photos.isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.person),
              ),
              title: Text(m.otherUser.profile?.displayName ?? 'Sin nombre'),
              onTap: () => Navigator.of(sheetContext).pop(m),
            ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;

    // Casi ninguna pista de OSM tiene nombre, asi que mandar `club.name`
    // tal cual llenaba los chats de "Club de tenis" sin decir donde. Para
    // esas se propone la direccion real y se deja confirmar/editar; las
    // que si tienen nombre pasan directas, sin preguntar nada.
    var placeName = club.name;
    if (!club.hasRealName) {
      final suggestion = await suggestedPlaceName(club);
      if (!mounted) return;
      final named = await askPlaceName(
        context,
        suggestion: suggestion,
        courtCount: club.courtCount,
      );
      if (named == null || !mounted) return;
      placeName = named;
    }

    // El club queda como sitio de la propuesta (nombre + coordenadas), asi
    // que `proposeSession` solo pregunta dia y hora. Las coordenadas dejan
    // al otro lado abrir el sitio en un mapa sin depender de que OSM tenga
    // web del club (raro: 0/40 cerca de Madrid, comprobado).
    await proposeSession(
      context,
      matchId: chosen.matchId,
      sport: Sport.tennis,
      presetPlaceName: placeName,
      presetPlaceLat: club.latitude,
      presetPlaceLng: club.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clubes de tenis cerca')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.matchpoint.app',
              ),
              MarkerLayer(
                markers: [
                  for (final club in _clubs)
                    Marker(
                      point: LatLng(club.latitude, club.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _openClubSheet(club),
                        child: Icon(
                          Icons.sports_tennis,
                          color: context.colors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: _searchPlace,
                decoration: InputDecoration(
                  hintText: 'Buscar ciudad o zona...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchPlace(_searchCtrl.text),
                        ),
                ),
              ),
            ),
          ),
          if (_loadingClubs)
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Positioned(
              bottom: 24,
              left: 12,
              right: 12,
              child: Material(
                // Aviso neutro, no `errorContainer`: es un servicio de
                // terceros ocupado, no un error de la app.
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 20,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _loadClubs(_center),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClubSheet extends StatelessWidget {
  final TennisClub club;
  final VoidCallback onProposeMatch;

  const _ClubSheet({required this.club, required this.onProposeMatch});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_tennis, color: context.colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club.name, style: context.textStyles.titleLarge),
                      Text(
                        club.courtCount == 1
                            ? '1 pista mapeada'
                            : '${club.courtCount} pistas mapeadas',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      if (!club.hasRealName)
                        Text(
                          'Sin nombre en OpenStreetMap · lo confirmas tú',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No comprobamos si hay pista libre a esa hora — le propones '
              'el club y el horario a tu match, y ya lo confirmáis vosotros.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onProposeMatch,
                icon: const Icon(Icons.send),
                label: const Text('Proponer partido aquí'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
