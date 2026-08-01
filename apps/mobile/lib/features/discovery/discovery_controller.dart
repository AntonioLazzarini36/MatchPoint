import 'package:flutter/foundation.dart';
import 'models/discover_profile.dart';
import 'models/sport.dart';
import 'models/swipe_type.dart';
import 'services/discovery_service.dart';

class DiscoveryController extends ChangeNotifier {
  final DiscoveryService service;
  DiscoveryController(this.service);

  Sport selectedSport = Sport.tennis;
  bool isPartnerMode = true;

  bool loading = false;
  String? error;

  final List<DiscoverProfile> _stack = [];
  List<DiscoverProfile> get stack => List.unmodifiable(_stack);

  /// Bumped whenever a card is rolled back into the stack after a failed
  /// swipe. The UI folds this into the card's `Key` so a rolled-back card
  /// is treated as a brand-new widget instead of resurrecting the
  /// `Dismissible` that was just dismissed — reusing that key crashes,
  /// since a dismissed `Dismissible` can't reappear under the same key.
  int generation = 0;

  Future<void> init() async => reload();

  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final feed = await service.fetchFeed(sport: selectedSport);
      _stack
        ..clear()
        ..addAll(feed);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setSport(Sport sport) {
    if (selectedSport == sport) return;
    selectedSport = sport;
    reload();
  }

  void setMode(bool partnerMode) {
    isPartnerMode = partnerMode;
    notifyListeners();
  }

  DiscoverProfile? get top => _stack.isNotEmpty ? _stack.last : null;

  // ✅ NUEVO: swipe del user concreto
  Future<({bool matched, String? matchId, DiscoverProfile user})> swipeUser({
    required DiscoverProfile user,
    required SwipeType type,
  }) async {
    // quitamos ese user concreto (por id) para no romper el stack
    final idx = _stack.lastIndexWhere((u) => u.userId == user.userId);
    if (idx == -1) {
      // ya no esta (puede pasar si se swypea rapido)
      return (matched: false, matchId: null, user: user);
    }

    final removed = _stack.removeAt(idx);
    notifyListeners();

    try {
      final res = await service.swipe(
        toUserId: removed.userId,
        sport: selectedSport,
        type: type,
      );
      return (matched: res.match, matchId: res.matchId, user: removed);
    } catch (e) {
      // rollback
      _stack.insert(idx, removed);
      generation++;
      notifyListeners();
      rethrow;
    }
  }

  // ✅ botones pueden seguir usando top
  Future<({bool matched, String? matchId, DiscoverProfile? user})>
  likeTop() async {
    final u = top;
    if (u == null) return (matched: false, matchId: null, user: null);
    final r = await swipeUser(user: u, type: SwipeType.like);
    return (matched: r.matched, matchId: r.matchId, user: r.user);
  }

  Future<void> passTop() async {
    final u = top;
    if (u == null) return;
    await swipeUser(user: u, type: SwipeType.pass);
  }
}
