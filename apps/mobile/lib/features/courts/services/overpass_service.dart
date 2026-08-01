import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/tennis_court.dart';

/// Queries Overpass (OpenStreetMap's public query API, no API key) for real
/// tennis courts near a point — `leisure=pitch` + `sport=tennis`, tagged by
/// anyone who's mapped a court on OSM. Third-party API, not our backend, so
/// this is a plain `http` call rather than going through `ApiClient`.
class OverpassService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

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

    final res = await http.post(
      Uri.parse(_endpoint),
      body: {'data': query},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Overpass query failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];

    return elements
        .map((e) {
          final m = e as Map<String, dynamic>;
          // Nodes have lat/lon directly; ways/relations only get one via
          // `out center`, under a nested `center` object.
          final center = m['center'] as Map<String, dynamic>?;
          final lat = (m['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
          final lon = (m['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();
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
