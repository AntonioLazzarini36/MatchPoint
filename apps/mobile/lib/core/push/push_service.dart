import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api.dart';

/// Notificaciones push.
///
/// Lo que resuelve: hasta ahora la app sólo se enteraba de un mensaje o una
/// propuesta sondeando cada pocos segundos **con la app abierta**. Cerrada no
/// llegaba nada, y en una app para quedar eso la mata — te escriben para
/// jugar el sábado y te enteras el lunes.
///
/// Tres cosas que conviene entender antes de tocar esto:
///
/// 1. **El token se registra al iniciar sesión, no al arrancar.** El backend
///    lo guarda contra el usuario autenticado, así que sin sesión no hay a
///    quién asociarlo.
/// 2. **El token puede cambiar solo** (reinstalación, restaurar copia de
///    seguridad, limpieza de datos). Por eso se escucha `onTokenRefresh`: sin
///    eso, la app deja de recibir notificaciones un día cualquiera y no hay
///    forma de saberlo desde dentro.
/// 3. **Desde Android 13 el permiso hay que pedirlo.** Antes bastaba con
///    declararlo en el manifest. Si no se pide, no llega nada y **tampoco
///    salta ningún error**: simplemente no suena nunca.
class PushService {
  PushService._();

  static bool _initialised = false;
  static String? _registeredToken;

  /// ¿Puede esta plataforma recibir push? En web haría falta configuración
  /// aparte (clave VAPID y un service worker propio) que no está montada, y
  /// en escritorio no existe FCM. Comprobarlo aquí evita que la app reviente
  /// al arrancar en Chrome durante el desarrollo.
  static bool get _supported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Arranca Firebase. Se llama una vez, antes de `runApp`.
  ///
  /// No lanza excepción si falla: quedarse sin notificaciones es molesto,
  /// pero que la app no abra es mucho peor.
  static Future<void> init() async {
    if (!_supported || _initialised) return;
    try {
      await Firebase.initializeApp();
      _initialised = true;
    } catch (e) {
      debugPrint('push: no se pudo inicializar Firebase: $e');
    }
  }

  /// Pide permiso, consigue el token y lo registra en el backend.
  ///
  /// Idempotente: se puede llamar en cada arranque y tras cada login sin
  /// comprobar antes si ya estaba hecho.
  static Future<void> registerCurrentDevice() async {
    if (!_supported || !_initialised) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // En Android 13+ esto abre el diálogo del sistema; en versiones
      // anteriores devuelve "autorizado" sin preguntar nada.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('push: el usuario ha denegado las notificaciones');
        return;
      }

      final token = await messaging.getToken();
      if (token == null) return;
      await _sendToBackend(token);

      // El token puede rotar sin que la app se entere de otra forma.
      messaging.onTokenRefresh.listen(_sendToBackend);
    } catch (e) {
      debugPrint('push: no se pudo registrar el dispositivo: $e');
    }
  }

  static Future<void> _sendToBackend(String token) async {
    try {
      await Api.client.post(
        '/me/devices',
        auth: true,
        body: {
          'token': token,
          'platform': kIsWeb
              ? 'web'
              : Platform.isIOS
              ? 'ios'
              : 'android',
        },
      );
      _registeredToken = token;
    } catch (e) {
      debugPrint('push: no se pudo guardar el token: $e');
    }
  }

  /// Da de baja el dispositivo al cerrar sesión.
  ///
  /// Importante hacerlo **antes** de borrar el token de sesión, porque el
  /// endpoint va autenticado. Si no se hiciera, quien entrase después en ese
  /// móvil recibiría las notificaciones de la cuenta anterior.
  static Future<void> unregisterCurrentDevice() async {
    if (!_supported || !_initialised) return;
    final token = _registeredToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    try {
      await Api.client.delete(
        '/me/devices',
        auth: true,
        body: {'token': token},
      );
      _registeredToken = null;
    } catch (e) {
      debugPrint('push: no se pudo dar de baja el token: $e');
    }
  }
}
