import 'dart:convert';
import '../../../core/network/api_error.dart';
import 'package:flutter/foundation.dart';
import 'package:match_point/core/network/api_client.dart';
import '../models/match_item.dart';

class MatchesService {
  final ApiClient api;
  MatchesService(this.api);

  Future<List<MatchItem>> fetchMatches() async {
    final res = await api.get('/matches', auth: true);

    if (kDebugMode) {
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se han podido cargar tus compañeros');
    }

    final decoded = jsonDecode(res.body);

    final List<dynamic> list = decoded is List
        ? decoded
        : (decoded['items'] as List<dynamic>? ??
              decoded['data'] as List<dynamic>? ??
              const <dynamic>[]);

    return list
        .map((e) => MatchItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> unmatch(String matchId) async {
    final res = await api.delete('/matches/$matchId', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido deshacer el match');
    }
  }
}
