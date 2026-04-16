import 'package:flutter/foundation.dart';
import 'api_client.dart';

class Api {
  static final ApiClient client = ApiClient(baseUrl: _baseUrl);

  static String get _baseUrl {
    // por lo que he entendido, mira la plataforma que quiere correr la app y entonces elige qué direccion usar
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://10.0.2.2:3000';
  }
  // por ejemplo, flutter run -d chrome hace que kIsWeb = true entonces usa ese, pero si escribes flutter run -d android == false,
  // o flutter run -d <id-del-emulador-android> → kIsWeb == false
}