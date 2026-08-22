import 'dart:convert';

import 'package:match_point/core/network/api_client.dart';
import 'package:match_point/features/discovery/models/sport.dart';
import '../models/proposal.dart';

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
      throw Exception(_message(res.body, 'No se pudo enviar la propuesta'));
    }

    return Proposal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<Proposal>> listForMatch(String matchId) async {
    final res = await api.get('/matches/$matchId/proposals', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('ListProposals failed: ${res.statusCode} ${res.body}');
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
      throw Exception(_message(res.body, 'No se pudo actualizar la propuesta'));
    }

    return Proposal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<UpcomingSession>> listUpcoming() async {
    final res = await api.get('/me/proposals', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('ListUpcoming failed: ${res.statusCode} ${res.body}');
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
      throw Exception('ListAwaitingFeedback failed: ${res.statusCode}');
    }

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => UpcomingSession.fromJson(e as Map<String, dynamic>))
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
  }) async {
    final res = await api.post(
      '/proposals/$proposalId/feedback',
      auth: true,
      body: {
        'played': played,
        'outcome': ?outcome,
        'wouldRepeat': ?wouldRepeat,
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_message(res.body, 'No se pudo guardar la respuesta'));
    }
  }

  /// El backend manda `{ "message": "..." }` en los 400/403 con texto ya
  /// redactado para el usuario — merece la pena mostrarlo en vez de un
  /// código de estado pelado.
  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // cuerpo no-JSON: nos quedamos con el mensaje genérico
    }
    return fallback;
  }
}
