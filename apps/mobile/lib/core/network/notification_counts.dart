import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Contadores para los badges de la barra de navegación, refrescados en
/// bucle mientras la app está abierta.
///
/// No son notificaciones push de verdad: sin push, la app solo puede
/// enterarse de algo nuevo mientras está en primer plano. Lo que esto
/// arregla es el agujero más grande que había — que sólo te enterabas de
/// un mensaje o una propuesta si entrabas tú a esa pestaña a mirar. Push
/// real (FCM/APNs) necesita credenciales externas, ver README.
///
/// Un único endpoint (`/me/notifications`) devuelve los dos números, para
/// no traerse la lista entera de matches sólo para contar.
class NotificationCounts extends ChangeNotifier {
  NotificationCounts._();
  static final NotificationCounts instance = NotificationCounts._();

  int unreadMessages = 0;
  int pendingProposals = 0;

  /// Quedadas ya pasadas de las que no has contado que ocurrio. Sin este
  /// contador, cerrar el bucle dependeria de que a alguien se le ocurriera
  /// entrar a mirar — que es justo lo que no pasa.
  int sessionsToConfirm = 0;

  Timer? _timer;

  /// Intervalo deliberadamente más lento que el polling del chat (4s): esto
  /// corre siempre que la app esté abierta, no sólo dentro de una
  /// conversación.
  static const _interval = Duration(seconds: 15);

  void start() {
    if (_timer != null) return;
    refresh();
    _timer = Timer.periodic(_interval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Silenciosa: un fallo de red aquí no debe molestar al usuario, el
  /// siguiente tick lo reintenta.
  Future<void> refresh() async {
    try {
      final res = await Api.client.get('/me/notifications', auth: true);
      if (res.statusCode < 200 || res.statusCode >= 300) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final unread = (data['unreadMessages'] as num?)?.toInt() ?? 0;
      final pending = (data['pendingProposals'] as num?)?.toInt() ?? 0;
      final toConfirm = (data['sessionsToConfirm'] as num?)?.toInt() ?? 0;
      if (unread == unreadMessages &&
          pending == pendingProposals &&
          toConfirm == sessionsToConfirm) {
        return;
      }

      unreadMessages = unread;
      pendingProposals = pending;
      sessionsToConfirm = toConfirm;
      notifyListeners();
    } catch (_) {
      // se reintenta en el siguiente tick
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
