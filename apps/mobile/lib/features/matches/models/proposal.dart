import 'package:match_point/features/discovery/models/sport.dart';

/// Estado de una propuesta. `cancelled` es que quien la hizo se echó
/// atrás; `declined` es que la otra persona dijo que no — separados a
/// propósito para poder redactarlos distinto en el chat.
enum ProposalStatus { pending, accepted, declined, cancelled }

extension ProposalStatusApi on ProposalStatus {
  static ProposalStatus fromApi(String v) {
    switch (v) {
      case 'ACCEPTED':
        return ProposalStatus.accepted;
      case 'DECLINED':
        return ProposalStatus.declined;
      case 'CANCELLED':
        return ProposalStatus.cancelled;
      default:
        return ProposalStatus.pending;
    }
  }
}

/// Un plan concreto para jugar, colgado de un match.
///
/// Antes de que esto existiera, "proponer un partido" era un mensaje de
/// chat normal: no se podía aceptar, no tenía estado, y desaparecía
/// scrolleando como cualquier otro texto.
class Proposal {
  final String id;
  final String matchId;
  final String proposedById;

  /// True si la propuesta la hiciste tú — lo calcula el backend, para que
  /// el cliente no tenga que comparar ids a mano para decidir entre
  /// "Aceptar/Rechazar" y "Cancelar".
  final bool mine;

  final Sport sport;
  final String? placeName;
  final double? placeLat;
  final double? placeLng;
  final DateTime scheduledAt;
  final ProposalStatus status;
  final DateTime createdAt;

  const Proposal({
    required this.id,
    required this.matchId,
    required this.proposedById,
    required this.mine,
    required this.sport,
    required this.placeName,
    required this.placeLat,
    required this.placeLng,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == ProposalStatus.pending;
  bool get hasCoordinates => placeLat != null && placeLng != null;

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
    id: json['id'] as String,
    matchId: json['matchId'] as String,
    proposedById: (json['proposedById'] ?? '').toString(),
    mine: json['mine'] == true,
    sport: SportApi.fromApi((json['sport'] ?? 'TENNIS').toString()),
    placeName: json['placeName']?.toString(),
    placeLat: (json['placeLat'] as num?)?.toDouble(),
    placeLng: (json['placeLng'] as num?)?.toDouble(),
    scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
    status: ProposalStatusApi.fromApi((json['status'] ?? 'PENDING').toString()),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}

/// Una propuesta aceptada y aún por jugar, más lo justo de la otra
/// persona para pintar una fila sin pedir su perfil aparte.
class UpcomingSession {
  final Proposal proposal;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherPhoto;

  const UpcomingSession({
    required this.proposal,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.otherPhoto,
  });

  /// El backend aplana la propuesta dentro del mismo objeto (`#[serde
  /// (flatten)]`), así que el propio json sirve de las dos cosas.
  factory UpcomingSession.fromJson(Map<String, dynamic> json) =>
      UpcomingSession(
        proposal: Proposal.fromJson(json),
        otherUserId: (json['otherUserId'] ?? '').toString(),
        otherDisplayName: (json['otherDisplayName'] ?? 'Sin nombre').toString(),
        otherPhoto: json['otherPhoto']?.toString(),
      );
}

/// Un partido ya jugado, tal como lo devuelve `GET /me/proposals/history`.
///
/// [played] y [outcome] son **lo que contaste tú**: `null` mientras no hayas
/// respondido. Lo que dijera la otra persona no llega, a propósito — enseñar
/// "dice que ganó él" al lado de "dices que ganaste tú" abre una discusión
/// que la app no puede arbitrar.
class PlayedSession {
  final Proposal proposal;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherPhoto;
  final bool? played;
  final String? outcome;

  const PlayedSession({
    required this.proposal,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.otherPhoto,
    required this.played,
    required this.outcome,
  });

  /// Si se sabe que no se jugó, no hay resultado que enseñar.
  bool get hasResult => played == true && outcome != null;

  /// "Ganaste" / "Perdiste" / "Empate", tal cual se pinta en la fila.
  String? get outcomeLabel {
    if (!hasResult) return null;
    return switch (outcome) {
      'WON' => 'Ganaste',
      'LOST' => 'Perdiste',
      'DRAW' => 'Empate',
      _ => null,
    };
  }

  factory PlayedSession.fromJson(Map<String, dynamic> json) => PlayedSession(
    proposal: Proposal.fromJson(json),
    otherUserId: (json['otherUserId'] ?? '').toString(),
    otherDisplayName: (json['otherDisplayName'] ?? 'Sin nombre').toString(),
    otherPhoto: json['otherPhoto']?.toString(),
    played: json['played'] as bool?,
    outcome: json['outcome']?.toString(),
  );
}
