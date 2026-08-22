import 'dart:convert';
import '../../../core/network/api_error.dart';
import 'package:match_point/core/network/api_client.dart';
import '../models/discover_profile.dart';
import '../models/sport.dart';
import '../models/swipe_response.dart';
import '../models/swipe_type.dart';
import 'package:flutter/foundation.dart';

class DiscoveryService {
  final ApiClient api;
  DiscoveryService(this.api);

  Future<List<DiscoverProfile>> fetchFeed({required Sport sport}) async {
    // ApiClient no tiene query params, asi que los montamos en la URL
    final res = await api.get(
      '/discover?sport=${Uri.encodeQueryComponent(sport.apiValue)}',
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se han podido cargar los perfiles');
    }

    final decoded = jsonDecode(res.body);

    // Soporta: List o { items: [...] } o { data: [...] }
    final List<dynamic> list = decoded is List
        ? decoded
        : (decoded['items'] as List<dynamic>? ??
              decoded['data'] as List<dynamic>? ??
              const <dynamic>[]);

    return list
        .map((e) => DiscoverProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SwipeResponse> swipe({
    required String toUserId,
    required Sport sport,
    required SwipeType type,
  }) async {
    final body = {
      'toUserId': toUserId,
      'sport': sport.apiValue,
      'type': type.apiValue,
    };

    if (kDebugMode) {
    }

    final res = await api.post('/swipes', body: body, auth: true);

    if (kDebugMode) {
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido registrar tu decisión');
    }

    return SwipeResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
