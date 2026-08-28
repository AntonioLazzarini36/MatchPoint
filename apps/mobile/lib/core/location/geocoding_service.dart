import 'dart:convert';
import '../../core/network/api_error.dart';
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
        // Hace falta para poder componer un nombre corto: sin esto sólo llega
        // `display_name`, que para Benalmádena viene como "29630,
        // Benalmádena, Costa del Sol Occidental, Málaga, Andalucía, España" —
        // seis niveles administrativos donde hacen falta dos.
        'addressdetails': '1',
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
      throw apiError(res, fallback: 'No se ha podido completar la operación');
    }

    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .map((e) {
          final m = e as Map<String, dynamic>;
          final lat = double.tryParse(m['lat']?.toString() ?? '');
          final lon = double.tryParse(m['lon']?.toString() ?? '');
          if (lat == null || lon == null) return null;
          return LocationResult(
            displayName: _placeName(m),
            latitude: lat,
            longitude: lon,
          );
        })
        .whereType<LocationResult>()
        .toList();
  }

  /// De código postal a municipio.
  ///
  /// Es la vía principal para elegir dónde vives, y no una alternativa al
  /// buscador libre: un código postal es un dato que la gente **sabe** y que
  /// se teclea igual siempre, mientras que escribir el nombre del sitio
  /// devuelve barrios, calles y urbanizaciones mezclados, y obliga a decidir
  /// cuál de los ocho resultados parecidos es el tuyo. Cinco dígitos dan un
  /// municipio y ya está.
  ///
  /// Va con `country=es` porque el formato de código postal es cosa de cada
  /// país y esta app es de aquí; el buscador por nombre sigue funcionando en
  /// todo el mundo, que es la salida para quien no esté en España.
  ///
  /// El nombre se compone de `addressdetails` en vez de usar el
  /// `display_name` que devuelve Nominatim: ese trae el código, el municipio,
  /// la comarca, la provincia, la comunidad y el país en una sola línea
  /// ("29639, Benalmádena, Costa del Sol Occidental, Málaga, Andalucía,
  /// España"), que no cabe en la tarjeta y no ayuda a reconocer nada.
  Future<List<LocationResult>> searchPostalCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'postalcode': trimmed,
        'country': 'es',
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
        'accept-language': 'es',
      },
    );

    final res = await http.get(
      uri,
      headers: {'User-Agent': 'MatchPointApp/1.0 (dev)'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido buscar el código postal');
    }

    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .map((e) {
          final m = e as Map<String, dynamic>;
          final lat = double.tryParse(m['lat']?.toString() ?? '');
          final lon = double.tryParse(m['lon']?.toString() ?? '');
          if (lat == null || lon == null) return null;
          return LocationResult(
            displayName: _placeName(m),
            latitude: lat,
            longitude: lon,
          );
        })
        .whereType<LocationResult>()
        .toList();
  }

  /// El nombre que se enseña y se guarda: **código postal y municipio**, y
  /// nada más.
  ///
  /// `display_name` de Nominatim trae la jerarquía administrativa entera
  /// ("29630, Benalmádena, Costa del Sol Occidental, Málaga, Andalucía,
  /// España"), que no cabe en una fila, no ayuda a reconocer el sitio y
  /// acababa guardada tal cual como la ciudad del perfil. Con el código
  /// delante queda "29630 · Benalmádena", que es como la gente identifica su
  /// zona.
  ///
  /// `village` antes que `town` por el mismo motivo que en `reverse`: en la
  /// Costa del Sol `town` devuelve nombres compuestos larguísimos
  /// ("Arroyo de la Miel-Benalmádena Costa") donde `village` da el municipio
  /// a secas.
  static String _placeName(Map<String, dynamic> m) {
    final address = m['address'] as Map<String, dynamic>?;
    if (address == null) return _shortFallback(m);

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = address[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final town = pick([
      'village',
      'town',
      'city',
      'municipality',
      'suburb',
      'neighbourhood',
    ]);
    final postcode = pick(['postcode']);

    if (town == null) return _shortFallback(m);
    return postcode == null ? town : '$postcode · $town';
  }

  /// Cuando no hay `addressdetails` utilizable: las dos primeras partes de
  /// `display_name`, que suelen ser el sitio y su municipio. Mejor que la
  /// cadena entera y mejor que quedarse sin nombre.
  static String _shortFallback(Map<String, dynamic> m) {
    final full = (m['display_name'] ?? '').toString();
    final parts = full.split(',').map((p) => p.trim()).toList();
    return parts.length <= 2 ? full : parts.take(2).join(', ');
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
