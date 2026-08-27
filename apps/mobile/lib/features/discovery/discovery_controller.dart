import 'package:flutter/foundation.dart';
import 'package:match_point/core/utils/app_sports.dart';

import 'models/discover_filters.dart';
import 'models/discover_profile.dart';
import 'models/sport.dart';
import 'models/swipe_type.dart';
import 'services/discovery_service.dart';

class DiscoveryController extends ChangeNotifier {
  final DiscoveryService service;

  /// Qué deportes pedirle al backend, en orden de preferencia.
  ///
  /// Mientras la app sea de un solo deporte esto es siempre `[tennis]` (ver
  /// `app_sports.dart`): la pregunta "¿a qué quieres jugar?" desapareció de
  /// la interfaz porque tenía una sola respuesta posible. La lista se
  /// mantiene —y el bucle de abajo que pide un feed por deporte también—
  /// porque encender el segundo deporte es volver a llenarla, no reescribir
  /// esto.
  final List<Sport> sports;

  /// Cuándo puedes jugar y contra qué nivel. Es la pregunta con la que
  /// arranca la pantalla; el feed es su respuesta.
  DiscoverFilters filters;

  DiscoveryController(
    this.service, {
    required List<Sport> sports,
    this.filters = DiscoverFilters.none,
  }) : sports = onlyEnabled(sports);

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

  /// Cambia los filtros y vuelve a pedir el feed. No se puede conservar el
  /// stack anterior: cambiar el "cuándo" cambia quién es candidato, así que
  /// lo que ya estaba en pantalla puede haber dejado de cumplir.
  Future<void> setFilters(DiscoverFilters next) async {
    filters = next;
    await reload();
  }

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
        sports.map(
          (sport) => service.fetchFeed(sport: sport, filters: filters),
        ),
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

  /// Marca a alguien como "quiero jugar" o "ahora no". La tarjeta sale de la
  /// lista al instante y vuelve si la petición falla.
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
