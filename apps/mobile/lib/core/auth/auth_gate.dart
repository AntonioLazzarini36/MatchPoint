import '../storage/token_storage.dart';

class AuthGate {
  Future<bool> isLoggedIn() async {
    final token = await TokenStorage.getToken();
    print("TOKEN EN AUTHGATE: $token");
    return token != null && token.isNotEmpty;
  }
}
