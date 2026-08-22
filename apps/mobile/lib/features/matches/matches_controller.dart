import 'package:flutter/foundation.dart';
import 'models/match_item.dart';
import 'services/matches_service.dart';

class MatchesController extends ChangeNotifier {
  final MatchesService service;
  MatchesController(this.service);

  bool loading = false;
  /// El error entero, no su texto: la vista necesita el tipo para
  /// distinguir un problema de red de uno del servidor.
  Object? error;

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
      error = e;
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
