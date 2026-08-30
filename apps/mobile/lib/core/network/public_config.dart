import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Lo que el servidor dice de sí mismo antes de que haya sesión.
///
/// Existe por un caso concreto: el enlace de "he olvidado mi contraseña" vive
/// en la pantalla de login, y ese flujo va por correo. Si esta instalación
/// tiene el correo apagado (`EMAIL_VERIFICATION_ENABLED=false`, lo normal
/// mientras no haya dominio verificado), el enlace lleva a un 503 — y un
/// enlace que siempre falla se lee como una app rota. Con esto se esconde.
///
/// No se puede preguntar por `/me`, que es donde vive el mismo dato para el
/// resto de la app: `/me` va autenticado y aquí justamente no hay sesión.
class PublicConfig {
  PublicConfig._();

  /// Se cachea en memoria: es configuración del servidor, no cambia mientras
  /// la app está abierta, y la pantalla de login se visita más de una vez.
  static bool? _emailEnabled;

  /// Por defecto **true**: si la consulta falla (sin red, servidor caído), es
  /// mejor enseñar el enlace y que el intento dé un error explicando qué
  /// pasa, que esconder para siempre la única forma de recuperar la cuenta.
  static Future<bool> emailEnabled() async {
    final cached = _emailEnabled;
    if (cached != null) return cached;

    try {
      final res = await Api.client.get('/app/config');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final value = data['emailEnabled'] as bool? ?? true;
        _emailEnabled = value;
        return value;
      }
    } catch (e) {
      debugPrint('config: no se ha podido leer /app/config: $e');
    }
    return true;
  }
}
