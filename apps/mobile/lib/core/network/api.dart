import 'api_client.dart';

class Api {
  static final ApiClient client = ApiClient(baseUrl: _baseUrl);

  // Para Flutter Web + backend local
  static const String _baseUrl = 'http://localhost:3000';

  // Si luego pruebas en Android emulator, cambia a:
  // static const String _baseUrl = 'http://10.0.2.2:3000';
}
