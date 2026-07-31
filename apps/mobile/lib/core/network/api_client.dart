import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = await _headers(auth: auth);

    return http.delete(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
  }

  /// Sube un archivo como multipart/form-data, a partir de sus bytes (no de
  /// un path de disco: `image_picker` en Flutter Web devuelve una blob URL,
  /// no un path real, y `MultipartFile.fromPath` necesita `dart:io`, que no
  /// existe en web — por eso bytes, que funciona en todas las plataformas).
  /// No reutiliza `_headers()` porque esa fija `Content-Type:
  /// application/json` — aquí necesitamos que `http.MultipartRequest` ponga
  /// su propio `multipart/form-data; boundary=...`.
  Future<http.Response> postMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    required String contentType,
    bool auth = false,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

    if (auth) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
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
