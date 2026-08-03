import 'package:match_point/features/onboarding/models/profile.dart';
import 'package:match_point/features/discovery/models/sport.dart';

class MatchItem {
  final String matchId;
  final DateTime createdAt;
  final Sport sport;
  final MatchUser otherUser;
  final MatchUser me;
  final LastMessagePreview? lastMessage;
  final int unreadCount;

  const MatchItem({
    required this.matchId,
    required this.createdAt,
    required this.sport,
    required this.otherUser,
    required this.me,
    required this.lastMessage,
    required this.unreadCount,
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

  const MatchUser({required this.userId, required this.profile});

  factory MatchUser.fromJson(Map<String, dynamic> json) => MatchUser(
    userId: json['userId'] as String,
    profile: json['profile'] == null
        ? null
        : Profile.fromJson(json['profile'] as Map<String, dynamic>),
  );
}
