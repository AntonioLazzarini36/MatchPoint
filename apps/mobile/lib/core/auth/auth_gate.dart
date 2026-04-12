import '../storage/token_storage.dart';

class AuthGate {
  Future<bool> isLoggedIn() async {
    final token = await TokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }
}
