import 'dart:convert';
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
    // ApiClient no tiene query params, así que los montamos en la URL
    final res = await api.get(
      '/discover?sport=${Uri.encodeQueryComponent(sport.apiValue)}',
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Discover failed: ${res.statusCode} ${res.body}');
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
      print('[SWIPE] POST /swipes body=${jsonEncode(body)}');
    }

    final res = await api.post('/swipes', body: body, auth: true);

    if (kDebugMode) {
      print('[SWIPE] status=${res.statusCode} body=${res.body}');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Swipe failed: ${res.statusCode} ${res.body}');
    }

    return SwipeResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
