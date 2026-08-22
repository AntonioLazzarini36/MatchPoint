import 'package:match_point/features/onboarding/models/profile.dart';
import 'package:match_point/features/discovery/models/skill_level.dart';
import 'package:match_point/features/discovery/models/sport.dart';

class MatchItem {
  final String matchId;
  final DateTime createdAt;
  final Sport sport;
  final MatchUser otherUser;
  final MatchUser me;
  final LastMessagePreview? lastMessage;
  final int unreadCount;

  /// Cuántas veces habéis jugado ya. Es la señal de confianza más fuerte de
  /// la app, porque es la única que no se puede inflar: sale de que alguien
  /// confirmó después de la quedada que se jugó.
  final int playedTogether;

  const MatchItem({
    required this.matchId,
    required this.createdAt,
    required this.sport,
    required this.otherUser,
    required this.me,
    required this.lastMessage,
    required this.unreadCount,
    this.playedTogether = 0,
  });

  factory MatchItem.fromJson(Map<String, dynamic> json) => MatchItem(
    matchId: json['matchId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    sport: SportApi.fromApi((json['sport'] ?? 'TENNIS').toString()),
    otherUser: MatchUser.fromJson(json['otherUser'] as Map<String, dynamic>),
    me: MatchUser.fromJson(json['me'] as Map<String, dynamic>),
    lastMessage: json['lastMessage'] == null
        ? null
        : LastMessagePreview.fromJson(
            json['lastMessage'] as Map<String, dynamic>,
          ),
    unreadCount: json['unreadCount'] as int,
    // Con `?? 0` y no `as int`: una app nueva contra un backend viejo no
    // debe reventar por un campo que todavia no manda.
    playedTogether: (json['playedTogether'] as num?)?.toInt() ?? 0,
  );
}

class LastMessagePreview {
  final String senderId;
  final String text;
  final DateTime createdAt;

  const LastMessagePreview({
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) =>
      LastMessagePreview(
        senderId: json['senderId'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class MatchUser {
  final String userId;
  final Profile? profile;

  /// El nivel por deporte viene dentro de `profile` en el JSON (el backend
  /// manda ahi un `DiscoverProfile` completo), pero el modelo `Profile` de
  /// Dart no lo guarda porque en `/me` es un campo hermano y no anidado. Se
  /// recoge aqui para que la lista de matches pueda enseñarlo sin pedir el
  /// perfil entero de cada persona.
  final Map<Sport, SkillLevel> skillLevels;

  const MatchUser({
    required this.userId,
    required this.profile,
    this.skillLevels = const {},
  });

  factory MatchUser.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map<String, dynamic>?;
    return MatchUser(
      userId: json['userId'] as String,
      profile: profileJson == null ? null : Profile.fromJson(profileJson),
      skillLevels: profileJson == null
          ? const {}
          : skillLevelsFromJson(profileJson['skillLevels']),
    );
  }
}
