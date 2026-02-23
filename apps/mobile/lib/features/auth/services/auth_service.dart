import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';

class AuthService {
  final ApiClient api;

  AuthService(this.api);

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
}
