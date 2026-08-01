import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/network/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../matches/models/match_item.dart';
import '../../matches/services/chat_service.dart';
import '../../matches/services/matches_service.dart';
import '../models/tennis_court.dart';
import '../services/overpass_service.dart';

/// Tennis courts near a point, real OpenStreetMap data — see one on the
/// map, tap it, and propose it to whichever match you want by sending a
/// message into that match's chat. Deliberately not more than that yet:
/// no booking/availability system, no dedicated "proposal" backend concept
/// — just a starting point per the "poco a poco" ask, built on
/// infrastructure that already exists (chat messages).
class TennisCourtsMapScreen extends StatefulWidget {
  const TennisCourtsMapScreen({super.key});

  @override
  State<TennisCourtsMapScreen> createState() => _TennisCourtsMapScreenState();
}

class _TennisCourtsMapScreenState extends State<TennisCourtsMapScreen> {
  // Madrid as a neutral default center — this screen doesn't read the
  // profile location from feat/manual-location (separate, unmerged
  // branch); the search box below is how you get to your actual area.
  static const _defaultCenter = LatLng(40.4168, -3.7038);

  final _mapController = MapController();
  final _overpass = OverpassService();
  final _searchCtrl = TextEditingController();

  LatLng _center = _defaultCenter;
  List<TennisCourt> _courts = [];
  bool _loadingCourts = false;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourts(_center);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourts(LatLng center) async {
    setState(() {
      _loadingCourts = true;
      _error = null;
    });
    try {
      final courts = await _overpass.nearby(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted) return;
      setState(() {
        _courts = courts;
        _loadingCourts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las pistas: $e';
        _loadingCourts = false;
      });
    }
  }

  Future<void> _searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _searching = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(
            queryParameters: {
              'q': trimmed,
              'format': 'jsonv2',
              'limit': '1',
            },
          );
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
      await _loadCourts(newCenter);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo buscar: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _openCourtSheet(TennisCourt court) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => _CourtSheet(
        court: court,
        onProposeMatch: () {
          Navigator.of(sheetContext).pop();
          _pickMatchAndPropose(court);
        },
      ),
    );
  }

  Future<void> _pickMatchAndPropose(TennisCourt court) async {
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
              '¿A quién le proponés ${court.name}?',
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

    final chatService = ChatService(Api.client);
    try {
      await chatService.sendMessage(
        matchId: chosen.matchId,
        text:
            '¿Jugamos en ${court.name}? 📍 '
            'https://www.openstreetmap.org/?mlat=${court.latitude}&mlon=${court.longitude}#map=17/${court.latitude}/${court.longitude}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Propuesta enviada a ${chosen.otherUser.profile?.displayName ?? 'tu match'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pistas de tenis cerca')),
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
                  for (final court in _courts)
                    Marker(
                      point: LatLng(court.latitude, court.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _openCourtSheet(court),
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
          if (_loadingCourts)
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
                color: context.colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colors.onErrorContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourtSheet extends StatelessWidget {
  final TennisCourt court;
  final VoidCallback onProposeMatch;

  const _CourtSheet({required this.court, required this.onProposeMatch});

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
                  child: Text(
                    court.name,
                    style: context.textStyles.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onProposeMatch,
                icon: const Icon(Icons.send),
                label: const Text('Proponer partido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
