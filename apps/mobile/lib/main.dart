import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'core/analytics/analytics.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  // Firebase toca canales de plataforma, así que el binding tiene que estar
  // listo antes.
  WidgetsFlutterBinding.ensureInitialized();

  // Sólo vertical. Se fija tambien en el manifest de Android y en el
  // Info.plist de iOS: esta llamada gobierna la app ya en marcha, pero el
  // sistema decide la orientacion **antes** de que Flutter arranque, asi que
  // sin la parte nativa se ve un giro momentaneo al abrir con el movil
  // tumbado. `portraitDown` queda fuera a proposito: abrir la app del reves
  // no es algo que nadie quiera.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Antes de `runApp` para que una notificación que abre la app en frío
  // encuentre Firebase ya arrancado. No lanza si falla: quedarse sin
  // notificaciones es molesto, que la app no abra es peor.
  await PushService.init();

  // Despues de `PushService.init`, que es quien arranca Firebase: sin eso
  // `FirebaseAnalytics.instance` no tiene a que agarrarse. Si Firebase no
  // arranco, `init` lo detecta y todos los eventos pasan a ser no-ops.
  Analytics.init();

  // Si ya hay sesion guardada hay que registrar el dispositivo igual: sin
  // esto solo se registraria al iniciar sesion, que es justo el caso raro —
  // lo normal es abrir la app con la sesion puesta y no pasar por el login
  // en semanas. Sin await para no retrasar la primera pantalla.
  unawaited(PushService.registerIfLoggedIn());

  runApp(const MatchPointApp());
}
