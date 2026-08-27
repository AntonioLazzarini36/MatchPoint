import 'dart:convert';

import 'package:match_point/core/network/api_client.dart';

import '../../discovery/models/sport.dart';

/// Cuánta gente hay ya jugando cerca de un sitio.
///
/// Sirve para contestar en el paso de ubicación —mientras la persona aún
/// está eligiendo— la pregunta que hasta ahora se contestaba sola al final:
/// "¿hay alguien aquí?". Rellenar cinco pantallas, subir una foto y
/// encontrarse un Descubrir vacío es la peor forma posible de averiguarlo.
///
/// Es el único servicio de la app que llama **sin token**: en el registro
/// todavía no hay cuenta (nada se crea hasta el último paso del wizard). El
/// endpoint devuelve un número y nada más, y va limitado por IP.
class DensityService {
  final ApiClient api;
  DensityService(this.api);

  /// `null` si no se puede saber (sin red, error del servidor). Quien llama
  /// debe tratarlo como "no lo sé" y no como cero: decirle a alguien que no
  /// hay nadie cuando en realidad falló la petición es mentirle en el punto
  /// exacto en el que decide si se queda.
  Future<int?> countNear({
    required double lat,
    required double lng,
    required int radiusKm,
    Sport sport = Sport.tennis,
  }) async {
    try {
      final res = await api.get(
        '/discover/density?lat=$lat&lng=$lng&radiusKm=$radiusKm'
        '&sport=${Uri.encodeQueryComponent(sport.apiValue)}',
        auth: false,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return null;
      return (body['count'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}
