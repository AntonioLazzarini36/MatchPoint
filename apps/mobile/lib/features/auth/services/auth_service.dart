import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';

class AuthService {
  final ApiClient api;

  AuthService(this.api);

  /// Comprueba si un email ya está registrado, sin crear nada — se llama
  /// al principio del flujo de registro (antes de entrar al onboarding)
  /// para no hacer perder el tiempo a nadie rellenando todo el wizard.
  Future<bool> isEmailAvailable(String email) async {
    final res = await api.get(
      '/auth/email-available?email=${Uri.encodeQueryComponent(email)}',
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('EmailAvailable check failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['available'] as bool;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final res = await api.post('/auth/login', body: request.toJson());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Login failed: ${res.body}');
    }
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final res = await api.post('/auth/register', body: request.toJson());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Register failed: ${res.body}');
    }
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  /// Revoca el refresh token guardado en el backend. Best-effort a
  /// propósito (igual que `auth::service::logout` en el backend): si no
  /// hay refresh token guardado o la llamada falla por red, el logout
  /// local (borrar los tokens guardados, ver `TokenStorage`) debe
  /// completarse igual.
  Future<void> logout() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      await api.post(
        '/auth/logout',
        body: {'refreshToken': refreshToken ?? ''},
      );
    } catch (_) {
      // Ignorado a propósito, ver comentario arriba.
    }
  }
}
