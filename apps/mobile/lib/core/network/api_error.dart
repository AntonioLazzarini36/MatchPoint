import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:match_point/core/i18n/app_locale.dart';

/// Un error que ha devuelto el servidor, con un mensaje que se puede enseñar.
///
/// Antes cada servicio lanzaba cosas como
/// `Exception('Swipe failed: 500 {"message":"Database error: duplicate key..."}')`
/// y eso llegaba **tal cual a la pantalla**: en inglés, con el código de
/// estado y con el cuerpo crudo del servidor dentro. Además de no decirle
/// nada a quien lo lee, filtraba detalles internos.
///
/// Aquí se traduce una vez y en un solo sitio.
class ApiException implements Exception {
  /// Lo que se le enseña a la persona.
  final String message;

  /// El código de estado, para que quien llama pueda decidir (reintentar,
  /// mandar al login...). No se enseña nunca.
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  /// ¿La sesión ha caducado? Es el único caso en que la app tiene que hacer
  /// algo por su cuenta además de enseñar el mensaje.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Construye el error a partir de la respuesta.
///
/// Prioridad:
/// 1. El campo `message` del cuerpo, si viene. El backend redacta ahí textos
///    pensados para leerse ("No se puede proponer una fecha que ya ha
///    pasado"), y son mejores que cualquier frase genérica.
/// 2. Una frase por familia de estado, si no.
///
/// Nunca el cuerpo crudo, ni el código de estado, ni el nombre del endpoint:
/// eso es información de diagnóstico, no un mensaje.
ApiException apiError(http.Response res, {String? fallback}) {
  final fromServer = _messageFrom(res.body);
  if (fromServer != null) return ApiException(fromServer, res.statusCode);

  return ApiException(fallback ?? _byStatus(res.statusCode), res.statusCode);
}

String? _messageFrom(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] is String) {
      final msg = (decoded['message'] as String).trim();
      if (msg.isNotEmpty) return msg;
    }
  } catch (_) {
    // Cuerpo que no es JSON (una página de error de un proxy, por ejemplo).
    // Enseñarlo sería peor que la frase genérica.
  }
  return null;
}

String _byStatus(int status) {
  if (status == 401) {
    return S.current.sessionExpired;
  }
  if (status == 403) {
    return S.current.noPermissionForThis;
  }
  if (status == 404) {
    return S.current.noLongerAvailable;
  }
  if (status == 429) {
    return S.current.tooManyRequests;
  }
  if (status >= 500) {
    return S.current.serverFailure;
  }
  return S.current.couldNotCompleteOperation;
}
