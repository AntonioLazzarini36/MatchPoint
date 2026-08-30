import 'package:flutter/foundation.dart';

import '../../app/router.dart';
import '../../app/routes.dart';
import '../ui/widgets/navigator.dart';

/// A dónde lleva un aviso.
///
/// Se separa de la navegación en sí para poder probarlo: la decisión ("un
/// mensaje abre su chat, un recordatorio abre Partidos") es la parte que se
/// rompe en silencio cuando el backend añade un tipo nuevo, y con el router
/// de por medio no se puede comprobar sin levantar media app.
enum PushTarget {
  /// Abrir la conversación de `matchId`.
  chat,

  /// La pestaña de Partidos: la quedada de la que habla el aviso está ahí.
  upcoming,

  /// No hay destino claro. Se abre la app y ya.
  none,
}

class PushDestination {
  const PushDestination(this.target, [this.matchId]);

  final PushTarget target;
  final String? matchId;

  static const nowhere = PushDestination(PushTarget.none);
}

/// Qué abrir cuando alguien toca una notificación.
///
/// Sin esto, tocar un aviso abría la app por donde la dejaste — que es
/// exactamente el sitio en el que no estaba lo que te acababan de contar. En
/// una app cuyo trabajo entero es que dos personas queden, el aviso es el
/// principio del recorrido, no un adorno: si al tocarlo hay que buscar la
/// conversación a mano, la mitad de la gente no la busca.
///
/// El `data` lo escribe el backend (`push::spawn_notify`) y sus tipos son
/// `message`, `match`, `proposal`, `reminder` y `feedback`. Todos menos
/// `feedback` traen `matchId`.
///
/// **Todo lo que llega aquí es texto.** FCM aplana el payload de datos a
/// pares de cadenas, así que nada se puede castear a otra cosa; y como el
/// aviso puede venir de una versión del backend más nueva que esta app, un
/// tipo desconocido no es un error: se abre la app y ya.
class PushNavigation {
  PushNavigation._();

  static PushDestination resolve(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return PushDestination.nowhere;

    final type = data['type']?.toString();
    final matchId = data['matchId']?.toString();
    final hasMatch = matchId != null && matchId.isNotEmpty;

    switch (type) {
      // Lo que ha pasado está dentro de la conversación: el mensaje, la
      // tarjeta de la propuesta, o el match recién hecho.
      case 'message':
      case 'match':
      case 'proposal':
        return hasMatch
            ? PushDestination(PushTarget.chat, matchId)
            : PushDestination.nowhere;

      // Estos dos hablan de una quedada concreta, y la pantalla que las
      // reúne (y donde se confirma si se jugó) es Partidos.
      case 'reminder':
      case 'feedback':
        return const PushDestination(PushTarget.upcoming);
    }

    return PushDestination.nowhere;
  }

  static void handle(Map<String, dynamic>? data) {
    final dest = resolve(data);

    switch (dest.target) {
      case PushTarget.chat:
        // Primero el shell y luego el chat encima: si se abriera el chat a
        // secas sobre una app recién arrancada, la flecha de atrás no
        // llevaría a ninguna parte. El `extra` del router va vacío a
        // propósito — aquí no hay `MatchItem` que pasar, y `ChatEntry` sabe
        // cargarlo por su id.
        NavigatorShell.goToTab(ShellTab.companions);
        _goShell();
        AppRouter.router.push('/chat/${dest.matchId}');
      case PushTarget.upcoming:
        NavigatorShell.goToTab(ShellTab.upcoming);
        _goShell();
      case PushTarget.none:
        if (kDebugMode) {
          debugPrint('push: aviso sin destino claro (${data?['type']})');
        }
    }
  }

  static void _goShell() {
    // `go` y no `push`: desde un aviso no se está "entrando más adentro" de
    // nada, se está empezando. Apilar una pantalla dejaría una flecha atrás
    // que no lleva a ningún sitio.
    AppRouter.router.go(AppRoutes.shell);
  }
}
