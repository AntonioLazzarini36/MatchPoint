import 'package:match_point/features/onboarding/models/profile.dart';

class MatchItem {
  final String matchId;
  final DateTime createdAt;
  final MatchUser otherUser;
  final MatchUser me;

  const MatchItem({
    required this.matchId,
    required this.createdAt,
    required this.otherUser,
    required this.me,
  });

  factory MatchItem.fromJson(Map<String, dynamic> json) => MatchItem(
        matchId: json['matchId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        otherUser:
            MatchUser.fromJson(json['otherUser'] as Map<String, dynamic>),
        me: MatchUser.fromJson(json['me'] as Map<String, dynamic>),
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