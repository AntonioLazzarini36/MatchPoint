import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _accessKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _accessKey);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
