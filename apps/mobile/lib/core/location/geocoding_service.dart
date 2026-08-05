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
  static const _reverseUrl = 'https://nominatim.openstreetmap.org/reverse';

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
  /// De coordenadas a una direccion legible ("Calle Rio Guadalhorce,
  /// Benalmadena"). Se usa para poner nombre a los sitios que en
  /// OpenStreetMap no lo tienen — mandarle a alguien "Pistas de tenis" a
  /// secas no le dice donde tiene que aparecer.
  ///
  /// Se llama **una sola vez, sobre el sitio ya elegido**, nunca sobre una
  /// lista entera: la politica de uso de Nominatim pide como maximo ~1
  /// peticion por segundo.
  ///
  /// Devuelve null si falla o no encuentra nada: es informacion opcional,
  /// asi que no debe romper el flujo de proponer una quedada.
  Future<String?> reverse(double latitude, double longitude) async {
    final uri = Uri.parse(_reverseUrl).replace(
      queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'jsonv2',
        'addressdetails': '1',
        // 17 = nivel de calle. Mas detalle devuelve el portal exacto, que
        // para "donde quedamos" es mas ruido que ayuda.
        'zoom': '17',
        'accept-language': 'es',
      },
    );

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'MatchPointApp/1.0 (dev)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final address = decoded['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      String? pick(List<String> keys) {
        for (final key in keys) {
          final value = address[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
        return null;
      }

      final where = pick(['road', 'pedestrian', 'neighbourhood', 'suburb']);
      // `village` antes que `town`: en la Costa del Sol, `town` devuelve
      // nombres compuestos larguisimos ("Arroyo de la Miel-Benalmadena
      // Costa") donde `village` da el municipio a secas ("Benalmadena").
      final town = pick(['village', 'town', 'city', 'municipality']);

      if (where == null && town == null) return null;
      if (where == null) return town;
      if (town == null) return where;
      return '$where, $town';
    } catch (_) {
      return null;
    }
  }
}
