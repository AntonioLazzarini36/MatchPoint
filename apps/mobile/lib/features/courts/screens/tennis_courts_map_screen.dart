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
import '../../onboarding/services/profile_service.dart';
import '../models/tennis_club.dart';
import '../services/overpass_service.dart';

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
      setState(() {
        _error = 'No se pudieron cargar los clubes: $e';
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

  Future<void> _proposeClub(TennisClub club) async {
    final day = await _pickWeekDay();
    if (day == null || !mounted) return;

    final time = await _pickTimeSlot();
    if (time == null || !mounted) return;

    final proposedAt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    await _pickMatchAndSend(club, proposedAt);
  }

  /// Calendario semanal navegable (no un mes entero) — se puede pasar a
  /// semanas siguientes, pero no a semanas anteriores a la actual.
  Future<DateTime?> _pickWeekDay() {
    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (_) => const _WeekCalendarPicker(),
    );
  }

  /// 8:00 a 22:00 en franjas de 15 min — un slider/reloj completo es
  /// overkill para "propón una hora orientativa", esto se elige de un
  /// vistazo.
  Future<TimeOfDay?> _pickTimeSlot() async {
    final slots = <TimeOfDay>[
      for (var m = 8 * 60; m <= 22 * 60; m += 15)
        TimeOfDay(hour: m ~/ 60, minute: m % 60),
    ];

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿A qué hora?', style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 16),
              Expanded(
                // Max extent (not a fixed count) so the number of columns
                // adapts to how much width is actually available — on a
                // narrow screen that means fewer, bigger buttons instead
                // of the same 4 columns squeezed down until the time
                // stops fitting.
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 88,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.0,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final slot = slots[i];
                    final label =
                        '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                    return OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(slot),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMatchAndSend(TennisClub club, DateTime proposedAt) async {
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

    final chatService = ChatService(Api.client);
    try {
      // Google Maps always works (built straight from lat/lng); the
      // court's own website is a bonus when OSM happens to have one
      // (rare in practice — checked, 0/40 near Madrid) so it's appended,
      // not relied on as the only link.
      final mapsLink =
          'https://www.google.com/maps/search/?api=1&query=${club.latitude},${club.longitude}';
      final websiteLine = club.website == null ? '' : '\n🌐 ${club.website}';

      await chatService.sendMessage(
        matchId: chosen.matchId,
        text:
            '¿Jugamos en ${club.name} el ${_formatDateTime(proposedAt)}? '
            '📍 $mapsLink$websiteLine',
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

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  String _formatDateTime(DateTime dt) {
    final weekday = _weekdays[dt.weekday - 1];
    final month = _months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$weekday ${dt.day} de $month a las $hh:$mm';
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
                color: context.colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: context.colors.onErrorContainer),
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
                label: const Text('Proponer partido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Week-view date picker: 7 days in a row, Monday-first, with prev/next
/// week navigation. Can't go to a week entirely before the current one
/// (can't propose a match in the past); individual past days within the
/// current week are shown but disabled. Forward navigation is unbounded —
/// no real reason to cap how far ahead you can propose a match.
class _WeekCalendarPicker extends StatefulWidget {
  const _WeekCalendarPicker();

  @override
  State<_WeekCalendarPicker> createState() => _WeekCalendarPickerState();
}

class _WeekCalendarPickerState extends State<_WeekCalendarPicker> {
  static const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  late final DateTime _today;
  late final DateTime _currentWeekStart;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _currentWeekStart = _mondayOf(_today);
    _weekStart = _currentWeekStart;
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  bool get _isCurrentWeek => _weekStart == _currentWeekStart;

  void _goToPreviousWeek() {
    if (_isCurrentWeek) return;
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  }

  void _goToNextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final weekEnd = days.last;
    final sameMonth = _weekStart.month == weekEnd.month;
    final rangeLabel = sameMonth
        ? '${_weekStart.day}-${weekEnd.day} de ${_months[_weekStart.month - 1]}'
        : '${_weekStart.day} ${_months[_weekStart.month - 1]} - '
              '${weekEnd.day} ${_months[weekEnd.month - 1]}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Qué día?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _isCurrentWeek ? null : _goToPreviousWeek,
                ),
                Text(rangeLabel, style: Theme.of(context).textTheme.bodyMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _goToNextWeek,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(children: [for (final day in days) _buildDayCell(day)]),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final isPast = day.isBefore(_today);
    final isToday = day == _today;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isToday ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isPast ? null : () => Navigator.of(context).pop(day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    _weekdaysShort[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      color: isPast ? scheme.outline : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isPast
                          ? scheme.outline
                          : (isToday ? scheme.onPrimaryContainer : scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
