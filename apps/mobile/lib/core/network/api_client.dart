import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../storage/token_storage.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  /// Shared by any concurrent 401s so they await one refresh instead of
  /// each firing their own — the backend rotates the refresh token on
  /// every use (deletes the old one), so a second concurrent attempt
  /// using the now-stale token would fail and wrongly log the user out
  /// even though the first attempt actually succeeded.
  Future<bool>? _refreshFuture;

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool isRetry = false,
  }) async {
    final headers = await _headers(auth: auth);
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    if (auth && res.statusCode == 401 && !isRetry && await _tryRefresh()) {
      return post(path, body: body, auth: auth, isRetry: true);
    }
    return res;
  }

  Future<http.Response> get(
    String path, {
    bool auth = false,
    bool isRetry = false,
  }) async {
    final headers = await _headers(auth: auth);
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: headers);
    if (auth && res.statusCode == 401 && !isRetry && await _tryRefresh()) {
      return get(path, auth: auth, isRetry: true);
    }
    return res;
  }

  Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool isRetry = false,
  }) async {
    final headers = await _headers(auth: auth);
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    if (auth && res.statusCode == 401 && !isRetry && await _tryRefresh()) {
      return patch(path, body: body, auth: auth, isRetry: true);
    }
    return res;
  }

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool isRetry = false,
  }) async {
    final headers = await _headers(auth: auth);
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    if (auth && res.statusCode == 401 && !isRetry && await _tryRefresh()) {
      return delete(path, body: body, auth: auth, isRetry: true);
    }
    return res;
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
    bool isRetry = false,
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
    final res = await http.Response.fromStream(streamed);

    if (auth && res.statusCode == 401 && !isRetry && await _tryRefresh()) {
      return postMultipart(
        path,
        fieldName: fieldName,
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        auth: auth,
        isRetry: true,
      );
    }
    return res;
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

  /// Attempts a silent token refresh. Returns whether it's now safe to
  /// retry the original request with a fresh access token.
  Future<bool> _tryRefresh() {
    return _refreshFuture ??= _doRefresh().whenComplete(
      () => _refreshFuture = null,
    );
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        // The refresh token itself was rejected (expired/revoked/already
        // rotated) — nothing left to recover locally. Clear both tokens
        // so AuthGate.isLoggedIn() goes false and the router's redirect
        // sends the user back to login on the next navigation.
        await TokenStorage.clear();
        return false;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await TokenStorage.saveToken(data['accessToken'] as String);
      await TokenStorage.saveRefreshToken(data['refreshToken'] as String);
      return true;
    } catch (_) {
      // Network hiccup, not a rejected token — leave tokens alone so a
      // later retry (once connectivity's back) can still succeed.
      return false;
    }
  }
}
