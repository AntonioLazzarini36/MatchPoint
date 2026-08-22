import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  // Firebase toca canales de plataforma, así que el binding tiene que estar
  // listo antes.
  WidgetsFlutterBinding.ensureInitialized();

  // Antes de `runApp` para que una notificación que abre la app en frío
  // encuentre Firebase ya arrancado. No lanza si falla: quedarse sin
  // notificaciones es molesto, que la app no abra es peor.
  await PushService.init();

  runApp(const MatchPointApp());
}
