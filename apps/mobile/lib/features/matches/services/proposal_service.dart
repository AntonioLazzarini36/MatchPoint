import 'dart:convert';
import '../../../core/network/api_error.dart';

import 'package:match_point/core/network/api_client.dart';
import 'package:match_point/features/discovery/models/skill_level.dart';
import 'package:match_point/features/discovery/models/sport.dart';
import '../models/proposal.dart';
import 'package:match_point/core/i18n/app_locale.dart';

class ProposalService {
  final ApiClient api;
  ProposalService(this.api);

  /// Crear una propuesta cancela automáticamente cualquier otra que
  /// siguiera pendiente en ese match (lo hace el backend) — dos ofertas
  /// vivas a la vez dejarían a ambas partes preguntándose cuál están
  /// aceptando.
  Future<Proposal> create({
    required String matchId,
    required Sport sport,
    required DateTime scheduledAt,
    String? placeName,
    double? placeLat,
    double? placeLng,
  }) async {
    final res = await api.post(
      '/matches/$matchId/proposals',
      body: {
        'sport': sport.apiValue,
        // El backend espera ISO-8601 con offset; `toUtc()` evita mandar
        // una hora local sin zona, que se interpretaría mal en servidor.
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'placeName': ?placeName,
        'placeLat': ?placeLat,
        'placeLng': ?placeLng,
      },
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotSendProposal);
    }

    return Proposal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<Proposal>> listForMatch(String matchId) async {
    final res = await api.get('/matches/$matchId/proposals', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotCompleteOperation);
    }

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => Proposal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `action` es ACCEPT/DECLINE (solo quien la recibió) o CANCEL (solo
  /// quien la hizo) — el backend rechaza la combinación equivocada con un
  /// 403, no hace falta duplicar esa regla aquí.
  Future<Proposal> respond({
    required String proposalId,
    required String action,
  }) async {
    final res = await api.patch(
      '/proposals/$proposalId',
      body: {'action': action},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotAnswerProposal);
    }

    return Proposal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<UpcomingSession>> listUpcoming() async {
    final res = await api.get('/me/proposals', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotLoadSessions);
    }

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => UpcomingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Quedadas ya pasadas que siguen esperando que cuentes que ocurrio.
  ///
  /// Endpoint aparte de `listUpcoming` a proposito: son dos preguntas
  /// distintas ("que tengo por jugar" y "que tengo por contar") y mezclarlas
  /// obligaria a filtrar por fecha en el cliente.
  Future<List<UpcomingSession>> listAwaitingFeedback() async {
    final res = await api.get('/me/sessions/played', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotLoadSessions);
    }

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => UpcomingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// El historial: partidos ya jugados, del más reciente al más antiguo.
  ///
  /// Hasta ahora, en cuanto un partido pasaba desaparecía de la app — y con
  /// él la única prueba de que esto sirve para algo. El resultado ya se
  /// guardaba desde hace tiempo (`SessionFeedback`), sólo que no había forma
  /// de volver a verlo.
  Future<List<PlayedSession>> listHistory() async {
    final res = await api.get('/me/proposals/history', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotLoadHistory);
    }

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => PlayedSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Guarda que paso. Contestar de nuevo corrige la respuesta anterior.
  ///
  /// `outcome` solo en tenis y solo si se jugo; el backend rechaza lo demas
  /// para no guardar resultados de partidos que no ocurrieron.
  Future<void> saveFeedback({
    required String proposalId,
    required bool played,
    String? outcome,
    bool? wouldRepeat,
    SkillLevel? assessedLevel,
    bool skipped = false,
  }) async {
    final res = await api.post(
      '/proposals/$proposalId/feedback',
      auth: true,
      body: {
        'played': played,
        'outcome': ?outcome,
        'wouldRepeat': ?wouldRepeat,
        'assessedLevel': ?assessedLevel?.apiValue,
        if (skipped) 'skipped': true,
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: S.current.couldNotSaveAnswer);
    }
  }

  /// El backend manda `{ "message": "..." }` en los 400/403 con texto ya
  /// redactado para el usuario — merece la pena mostrarlo en vez de un
  /// código de estado pelado.
}
