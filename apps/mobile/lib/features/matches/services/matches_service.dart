import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:match_point/core/network/api_client.dart';
import '../models/match_item.dart';

class MatchesService {
  final ApiClient api;
  MatchesService(this.api);

  Future<List<MatchItem>> fetchMatches() async {
    final res = await api.get('/matches', auth: true);

    if (kDebugMode) {
      print('[MATCHES] status=${res.statusCode} body=${res.body}');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Matches failed: ${res.statusCode} ${res.body}');
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
}