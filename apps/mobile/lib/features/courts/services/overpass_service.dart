import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/tennis_court.dart';

/// Queries Overpass (OpenStreetMap's public query API, no API key) for real
/// tennis courts near a point — `leisure=pitch` + `sport=tennis`, tagged by
/// anyone who's mapped a court on OSM. Third-party API, not our backend, so
/// this is a plain `http` call rather than going through `ApiClient`.
class OverpassService {
  // The main public instance (overpass-api.de) is free and shared by every
  // app that uses Overpass worldwide, so it regularly gets overloaded and
  // 504s — observed firsthand while testing this. Falls through a couple of
  // other public mirrors before giving up, rather than being a hard
  // single-point-of-failure on the flakiest one.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  Future<List<TennisCourt>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 8000,
  }) async {
    final query =
        '[out:json][timeout:20];'
        '('
        'node["leisure"="pitch"]["sport"="tennis"](around:$radiusMeters,$latitude,$longitude);'
        'way["leisure"="pitch"]["sport"="tennis"](around:$radiusMeters,$latitude,$longitude);'
        ');'
        'out center 40;';

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final res = await http
            .post(Uri.parse(endpoint), body: {'data': query})
            .timeout(const Duration(seconds: 15));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          lastError = Exception(
            '$endpoint failed: ${res.statusCode}',
          );
          continue;
        }

        return _parse(res.body);
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw Exception('Todos los servidores de Overpass fallaron: $lastError');
  }

  List<TennisCourt> _parse(String body) {
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

          return TennisCourt(
            id: '${m['type']}/${m['id']}',
            name: (name == null || name.isEmpty) ? 'Pista de tenis' : name,
            latitude: lat,
            longitude: lon,
          );
        })
        .whereType<TennisCourt>()
        .toList();
  }
}
