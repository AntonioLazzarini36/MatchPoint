class Profile {
  final String id;
  final String displayName;
  final List<String> photos;

  Profile({required this.id, required this.displayName, required this.photos});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: (json['displayName'] ?? '') as String,
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
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
