import 'dart:convert';
import '../../../core/network/api_error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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
      throw apiError(res, fallback: S.current.couldNotCheckEmail);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['available'] as bool;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final res = await api.post('/auth/login', body: request.toJson());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotSignIn);
    }
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final res = await api.post('/auth/register', body: request.toJson());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotCreateAccount);
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
      throw apiError(res, fallback: S.current.couldNotSendCode);
    }
  }

  /// Devuelve true si el código era correcto. Lanza con el motivo real
  /// (caducado, demasiados intentos) si no.
  /// Pide un código para recuperar la contraseña.
  ///
  /// **El backend contesta lo mismo exista la cuenta o no** (ver
  /// `auth::service::request_password_reset`), así que la app no puede — ni
  /// debe — decir "ese correo no está registrado": eso convertiría la
  /// pantalla en un detector de quién tiene cuenta aquí.
  Future<void> requestPasswordReset(String email) async {
    final res = await api.post(
      '/auth/forgot-password',
      body: {'email': email},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotSendCode);
    }
  }

  /// Cambia la contraseña con el código recibido por correo.
  ///
  /// Al terminar, el backend borra todas las sesiones de esa cuenta, así que
  /// después de esto hay que iniciar sesión otra vez — también en el móvil
  /// donde estuviera abierta.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await api.post(
      '/auth/reset-password',
      body: {'email': email, 'code': code, 'newPassword': newPassword},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotChangePassword);
    }
  }

  Future<void> verifyEmail(String code) async {
    final res = await api.post(
      '/auth/verify-email',
      body: {'code': code},
      auth: true,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotVerifyEmail);
    }
  }

  /// El backend manda `{"message": "..."}` ya redactado en castellano; si
  /// por lo que sea no viene, se usa el texto genérico.

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
