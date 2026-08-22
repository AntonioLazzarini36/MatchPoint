import 'package:flutter/foundation.dart';
import 'models/match_item.dart';
import 'models/proposal.dart';
import 'services/matches_service.dart';
import 'services/proposal_service.dart';

class MatchesController extends ChangeNotifier {
  final MatchesService service;
  final ProposalService proposals;
  MatchesController(this.service, this.proposals);

  bool loading = false;
  /// El error entero, no su texto: la vista necesita el tipo para
  /// distinguir un problema de red de uno del servidor.
  Object? error;

  final List<MatchItem> _matches = [];
  List<MatchItem> get matches => List.unmodifiable(_matches);

  /// La quedada viva de cada match, indexada por `matchId`.
  ///
  /// La lista de matches no la trae: son dos endpoints distintos y no tiene
  /// sentido meter la agenda dentro de `/matches`. Se cruzan aqui porque es
  /// lo que decide como se agrupa y se ordena la pantalla — sin esto, la
  /// lista solo puede ordenarse por hora del ultimo mensaje, que es
  /// exactamente el criterio de una app de chat y no de una de quedar a
  /// jugar.
  final Map<String, Proposal> _sessionByMatch = {};
  Proposal? sessionFor(String matchId) => _sessionByMatch[matchId];

  Future<void> init() async => reload();

  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // En paralelo: son independientes y encadenarlos solo haria esperar
      // el doble.
      final results = await Future.wait([
        service.fetchMatches(),
        proposals.listUpcoming(),
      ]);
      _matches
        ..clear()
        ..addAll(results[0] as List<MatchItem>);

      _sessionByMatch.clear();
      for (final s in results[1] as List<UpcomingSession>) {
        // `listUpcoming` ya viene ordenada por fecha, asi que la primera de
        // cada match es la mas proxima — que es la unica que interesa
        // enseñar en una fila.
        _sessionByMatch.putIfAbsent(s.proposal.matchId, () => s.proposal);
      }
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
