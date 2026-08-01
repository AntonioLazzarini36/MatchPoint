import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../models/tennis_club.dart';

class _RawCourt {
  final String id;
  final String? name;
  final double lat;
  final double lon;

  const _RawCourt({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });
}

/// Queries Overpass (OpenStreetMap's public query API, no API key) for real
/// tennis courts near a point, then groups them into clubs by proximity —
/// see the doc comment on [TennisClub] for why. Third-party API, not our
/// backend, so this is a plain `http` call rather than going through
/// `ApiClient`.
class OverpassService {
  // Only mirrors manually confirmed to return complete, correct data —
  // some public mirrors respond fast but with an empty/stale dataset
  // (overpass.osm.ch returned 0 results for a query that has 40 real
  // matches), which is worse than an honest timeout since it would show
  // "no clubs found" when there are some. The main instance is free and
  // shared by every app that uses Overpass worldwide, so it regularly gets
  // overloaded and 504s — observed firsthand while testing this — hence
  // the fallback instead of a hard single point of failure.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  static const _clusterRadiusMeters = 150.0;

  Future<List<TennisClub>> nearbyClubs({
    required double latitude,
    required double longitude,
    int radiusMeters = 10000,
  }) async {
    final query =
        '[out:json][timeout:20];'
        '('
        'node["leisure"="pitch"]["sport"="tennis"](around:$radiusMeters,$latitude,$longitude);'
        'way["leisure"="pitch"]["sport"="tennis"](around:$radiusMeters,$latitude,$longitude);'
        ');'
        'out center 200;';

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final res = await http
            .post(Uri.parse(endpoint), body: {'data': query})
            .timeout(const Duration(seconds: 15));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          lastError = Exception('$endpoint failed: ${res.statusCode}');
          continue;
        }

        final courts = _parse(res.body);
        return _clusterIntoClubs(courts);
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw Exception('Todos los servidores de Overpass fallaron: $lastError');
  }

  List<_RawCourt> _parse(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];

    return elements
        .map((e) {
          final m = e as Map<String, dynamic>;
          // Nodes have lat/lon directly; ways/relations only get one via
          // `out center`, under a nested `center` object.
          final center = m['center'] as Map<String, dynamic>?;
          final lat =
              (m['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
          final lon =
              (m['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) return null;

          final tags = m['tags'] as Map<String, dynamic>? ?? const {};
          final name = (tags['name'] as String?)?.trim();

          return _RawCourt(
            id: '${m['type']}/${m['id']}',
            name: (name == null || name.isEmpty) ? null : name,
            lat: lat,
            lon: lon,
          );
        })
        .whereType<_RawCourt>()
        .toList();
  }

  /// Greedy proximity clustering: each court joins the first existing
  /// cluster whose first member is within [_clusterRadiusMeters], or
  /// starts a new one. Good enough for "these are obviously the same
  /// club's courts" — not trying to be a general clustering algorithm.
  List<TennisClub> _clusterIntoClubs(List<_RawCourt> courts) {
    final clusters = <List<_RawCourt>>[];

    for (final court in courts) {
      List<_RawCourt>? target;
      for (final cluster in clusters) {
        final rep = cluster.first;
        if (_distanceMeters(rep.lat, rep.lon, court.lat, court.lon) <=
            _clusterRadiusMeters) {
          target = cluster;
          break;
        }
      }
      if (target != null) {
        target.add(court);
      } else {
        clusters.add([court]);
      }
    }

    return clusters.map((cluster) {
      final named = cluster.firstWhere(
        (c) => c.name != null,
        orElse: () => cluster.first,
      );
      final avgLat =
          cluster.map((c) => c.lat).reduce((a, b) => a + b) / cluster.length;
      final avgLon =
          cluster.map((c) => c.lon).reduce((a, b) => a + b) / cluster.length;

      return TennisClub(
        id: cluster.first.id,
        name: named.name ?? 'Club de tenis',
        courtCount: cluster.length,
        latitude: avgLat,
        longitude: avgLon,
      );
    }).toList();
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);
}
