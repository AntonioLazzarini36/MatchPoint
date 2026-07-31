import '../network/api.dart';
import '../storage/token_storage.dart';
import '../../features/onboarding/services/profile_service.dart';

class AuthGate {
  Future<bool> isLoggedIn() async {
    final token = await TokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  /// El registro se completa entero al final del onboarding (usuario +
  /// perfil + al menos 1 foto, todo junto) — si esto devuelve `false`
  /// estando logueado, es que quedó una cuenta a medias de un intento
  /// anterior interrumpido, y hay que volver a mandar al onboarding.
  Future<bool> hasCompleteProfile() async {
    try {
      final me = await ProfileService(Api.client).getMe();
      final profile = me.profile;
      return profile != null && profile.photos.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
