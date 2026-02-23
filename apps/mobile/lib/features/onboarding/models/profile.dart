class Profile {
  final String id;
  final String displayName;

  Profile({required this.id, required this.displayName});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: (json['displayName'] ?? '') as String,
    );
  }
}

class MeResponse {
  final String id;
  final String email;
  final Profile? profile;

  MeResponse({required this.id, required this.email, required this.profile});

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      id: json['id'] as String,
      email: (json['email'] ?? '') as String,
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(json['profile']),
    );
  }
}
