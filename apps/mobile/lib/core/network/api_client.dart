import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = await _headers(auth: auth);

    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> get(String path, {bool auth = false}) async {
    final headers = await _headers(auth: auth);

    return http.get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  Future<http.Response> patch(
    String path, {
      Map<String, dynamic>? body,
      bool auth = false,
    }) async {
      final headers = await _headers(auth: auth);
      
      return http.patch(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }
}
