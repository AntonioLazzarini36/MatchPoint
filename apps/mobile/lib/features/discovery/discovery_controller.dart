import 'package:flutter/foundation.dart';
import 'models/discover_profile.dart';
import 'models/sport.dart';
import 'models/swipe_type.dart';
import 'services/discovery_service.dart';

class DiscoveryController extends ChangeNotifier {
  final DiscoveryService service;

  /// Qué deportes pedirle al backend, en orden de preferencia.
  ///
  /// Es `Preferences.sportsWanted` (lo que el usuario quiere *ver*), con
  /// `Profile.sports` (lo que *juega*) como valor por defecto cuando no ha
  /// tocado esa preferencia — ver `discovery_screen.dart`, que resuelve
  /// las dos cosas contra `/me` antes de instanciar esto. Hasta
  /// 2026-08-04 esto miraba solo `Profile.sports` y `sportsWanted` se
  /// guardaba sin que nadie lo leyera nunca: la preferencia existía en
  /// Ajustes pero no hacía absolutamente nada.
  ///
  /// Si acaba vacío (perfil sin deportes, no debería pasar tras el
  /// onboarding) cae a tenis, para no dejar el feed vacío para siempre.
  final List<Sport> sports;

  DiscoveryController(this.service, {required List<Sport> sports})
    : sports = sports.isEmpty ? const [Sport.tennis] : sports;

  bool loading = false;

  /// El error entero, no su texto: la vista necesita el tipo para
  /// distinguir un problema de red de uno del servidor.
  Object? error;

  final List<DiscoverProfile> _stack = [];
  List<DiscoverProfile> get stack => List.unmodifiable(_stack);

  /// Bumped whenever a card is rolled back into the stack after a failed
  /// swipe. The UI folds this into the card's `Key` so a rolled-back card
  /// is treated as a brand-new widget instead of resurrecting the
  /// `Dismissible` that was just dismissed — reusing that key crashes,
  /// since a dismissed `Dismissible` can't reappear under the same key.
  int generation = 0;

  Future<void> init() async => reload();

  /// El backend solo filtra por un deporte a la vez (`?sport=`), así que
  /// para "varios deportes a la vez" pedimos un feed por cada deporte
  /// buscado y los unimos por `userId` — un candidato que encaja en más
  /// de uno solo aparece una vez.
  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final feeds = await Future.wait(
        sports.map((sport) => service.fetchFeed(sport: sport)),
      );
      final merged = <String, DiscoverProfile>{};
      for (final feed in feeds) {
        for (final profile in feed) {
          merged.putIfAbsent(profile.userId, () => profile);
        }
      }
      _stack
        ..clear()
        ..addAll(merged.values);
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Un candidato puede encajar en más de uno de los deportes buscados —
  /// el swipe (y un eventual match) es por deporte, así que hay que elegir
  /// uno solo. Usamos el primero en común, en el orden de `sports`, para
  /// que sea determinista.
  Sport _sportFor(DiscoverProfile user) {
    for (final sport in sports) {
      if (user.sports.contains(sport)) return sport;
    }
    return sports.first;
  }

  /// Swipea un perfil concreto — cualquiera de las tarjetas visibles en la
  /// fila horizontal, no solo "la de arriba" (ya no existe ese concepto,
  /// ver discovery_screen.dart).
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
        sport: _sportFor(removed),
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
}
