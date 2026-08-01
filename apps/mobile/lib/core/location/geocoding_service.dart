import 'dart:convert';
import 'package:http/http.dart' as http;

import 'location_result.dart';

/// Wraps Nominatim (OpenStreetMap's free geocoding API, no API key) so the
/// user can type "Málaga", "Benalmádena", "Innsbruck"... and pick from
/// real place suggestions — Hinge-style manual location, never device GPS.
///
/// This is a third-party API, not our own backend, so it's called directly
/// with a plain `http` request rather than through `ApiClient`. Nominatim's
/// usage policy (https://operations.osmfoundation.org/policies/nominatim/)
/// asks for a max of 1 request/second and an identifying User-Agent —
/// callers are expected to debounce keystrokes before calling `search`.
class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<LocationResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': '0',
        'limit': '8',
        'accept-language': 'es',
      },
    );

    final res = await http.get(
      uri,
      // Custom User-Agent is honored on native platforms; browsers control
      // this header themselves on Flutter Web and send the page's Referer
      // instead, which Nominatim's policy also accepts.
      headers: {'User-Agent': 'MatchPointApp/1.0 (dev)'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Geocoding search failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .map((e) {
          final m = e as Map<String, dynamic>;
          final lat = double.tryParse(m['lat']?.toString() ?? '');
          final lon = double.tryParse(m['lon']?.toString() ?? '');
          if (lat == null || lon == null) return null;
          return LocationResult(
            displayName: (m['display_name'] ?? '').toString(),
            latitude: lat,
            longitude: lon,
          );
        })
        .whereType<LocationResult>()
        .toList();
  }
}
