import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Los eventos que hacen falta para saber **dónde se cae la gente**.
///
/// Hasta ahora la app no medía nada, así que dar la APK a veinte personas
/// enseñaba lo mismo que no dárselas: no había forma de saber cuántas
/// terminan el registro, en cuál de los cinco pasos abandonan, cuántas llegan
/// a ver un perfil o cuántas acaban proponiendo un partido. Eso es justo la
/// única pregunta que importa ahora, y también lo primero que mira cualquiera
/// que se plantee poner dinero.
///
/// Dos decisiones a propósito:
///
/// **No se manda quién es nadie.** Ni `setUserId`, ni el email, ni el nombre,
/// ni las coordenadas. Firebase asigna su propio identificador de instalación
/// y con eso basta para contar embudos. Lo que se mide es *qué pasa*, no
/// *quién lo hace* — y así la política de privacidad puede decir exactamente
/// eso sin letra pequeña.
///
/// **Nada de esto puede romper la app.** Cada llamada va envuelta: una
/// analítica que falla es un dato que se pierde; una analítica que lanza es
/// una pantalla que no carga. Los nombres van en snake_case y sin los
/// prefijos reservados (`firebase_`, `google_`, `ga_`), que Firebase rechaza.
class Analytics {
  static FirebaseAnalytics? _instance;

  /// Se llama después de `Firebase.initializeApp`. Si Firebase no arrancó
  /// (falta `google-services.json`, por ejemplo), esto se queda a null y todo
  /// lo demás son no-ops silenciosos.
  static void init() {
    try {
      _instance = FirebaseAnalytics.instance;
    } catch (e) {
      debugPrint('analytics no disponible: $e');
    }
  }

  /// El observador que registra los cambios de pantalla solo. Se engancha al
  /// router; devuelve null si Firebase no está, y quien llama debe filtrarlo.
  static FirebaseAnalyticsObserver? get observer {
    final a = _instance;
    return a == null ? null : FirebaseAnalyticsObserver(analytics: a);
  }

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    final a = _instance;
    if (a == null) return;
    try {
      await a.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('analytics "$name" fallo: $e');
    }
  }

  // --- El embudo del registro -------------------------------------------
  //
  // Es el tramo que mas importa: todo lo demas de la app solo lo ve quien
  // haya llegado hasta el final de esto.

  /// Alguien abre el asistente de registro.
  static Future<void> onboardingStart() => _log('onboarding_start');

  /// Un paso completado, identificado por nombre y no por numero: si manana
  /// se reordenan los pasos, un embudo guardado por indices pasa a mentir
  /// sin avisar.
  static Future<void> onboardingStep(String step) =>
      _log('onboarding_step', {'step': step});

  /// La cuenta y el perfil existen ya en el servidor.
  static Future<void> signupCompleted() => _log('signup_completed');

  /// Se abandono el registro a medias, y desde donde.
  static Future<void> onboardingAbandoned(String step) =>
      _log('onboarding_abandoned', {'step': step});

  // --- Descubrir ---------------------------------------------------------

  static Future<void> discoverLoaded({
    required int count,
    required bool filtered,
  }) => _log('discover_loaded', {'count': count, 'filtered': filtered});

  /// Feed vacio. `filtered` distingue "no hay nadie" de "no hay nadie *con
  /// estos filtros*", que son dos problemas distintos con dos arreglos
  /// distintos.
  static Future<void> discoverEmpty({required bool filtered}) =>
      _log('discover_empty', {'filtered': filtered});

  static Future<void> filterChanged({
    required bool byTime,
    required bool byLevel,
  }) => _log('discover_filter_used', {'when': byTime, 'level': byLevel});

  static Future<void> playerLiked({required bool instantMatch}) =>
      _log('player_liked', {'instant_match': instantMatch});

  static Future<void> playerPassed() => _log('player_passed');

  // --- Lo que de verdad cuenta como exito --------------------------------

  static Future<void> matchCreated() => _log('match_created');

  static Future<void> messageSent() => _log('message_sent');

  static Future<void> proposalCreated() => _log('proposal_created');

  static Future<void> proposalAnswered(String action) =>
      _log('proposal_answered', {'action': action});

  /// El final del bucle: alguien cuenta que jugo. Es la metrica de verdad —
  /// no registros, no matches: partidos.
  static Future<void> sessionPlayed({required bool played}) =>
      _log('session_feedback', {'played': played});
}
