import 'package:flutter/foundation.dart';
import 'models/match_item.dart';
import 'services/matches_service.dart';

class MatchesController extends ChangeNotifier {
  final MatchesService service;
  MatchesController(this.service);

  bool loading = false;
  String? error;

  final List<MatchItem> _matches = [];
  List<MatchItem> get matches => List.unmodifiable(_matches);

  Future<void> init() async => reload();

  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final res = await service.fetchMatches();
      _matches
        ..clear()
        ..addAll(res);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}