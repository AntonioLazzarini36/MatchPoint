import 'dart:convert';
import '../../../core/network/api_error.dart';
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
      throw apiError(res, fallback: 'No se ha podido comprobar el email');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['available'] as bool;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final res = await api.post('/auth/login', body: request.toJson());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido iniciar sesión');
    }
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final res = await api.post('/auth/register', body: request.toJson());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido crear la cuenta');
    }
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  /// Pide (o reenvía) el código de verificación al email de la cuenta.
  ///
  /// El backend limita los reenvíos a uno por minuto y responde 429 con el
  /// tiempo que falta, así que el mensaje de error se pasa tal cual: ya
  /// viene redactado para enseñarse.
  Future<void> sendVerificationCode() async {
    final res = await api.post('/auth/send-verification', auth: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_message(res.body, 'No se pudo enviar el código'));
    }
  }

  /// Devuelve true si el código era correcto. Lanza con el motivo real
  /// (caducado, demasiados intentos) si no.
  Future<void> verifyEmail(String code) async {
    final res = await api.post(
      '/auth/verify-email',
      body: {'code': code},
      auth: true,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_message(res.body, 'No se pudo verificar el email'));
    }
  }

  /// El backend manda `{"message": "..."}` ya redactado en castellano; si
  /// por lo que sea no viene, se usa el texto genérico.
  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // cuerpo no-JSON: nos quedamos con el generico
    }
    return fallback;
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
