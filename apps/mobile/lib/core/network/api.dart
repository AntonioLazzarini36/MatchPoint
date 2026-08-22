import 'package:flutter/foundation.dart';
import 'api_client.dart';

class Api {
  static final ApiClient client = ApiClient(baseUrl: _baseUrl);

  /// Prioridad: `--dart-define=API_BASE_URL=...` siempre gana si se pasa —
  /// es lo que hay que usar para probar en un móvil físico (mismo WiFi que
  /// el ordenador de desarrollo): ni `localhost` ni `10.0.2.2` llegan al
  /// backend desde un dispositivo real, hace falta la IP LAN real del
  /// ordenador (ver README, sección "Probar en el móvil").
  static String get _baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    // por lo que he entendido, mira la plataforma que quiere correr la app y entonces elige que direccion usar
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://10.0.2.2:3000';
  }

  // por ejemplo, flutter run -d chrome hace que kIsWeb = true entonces usa ese, pero si escribes flutter run -d android == false,
  // o flutter run -d <id-del-emulador-android> → kIsWeb == false (fallback,
  // válido solo en el emulador Android, no en un móvil físico)
}
