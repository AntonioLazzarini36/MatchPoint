import 'package:match_point/features/discovery/models/sport.dart';

class Profile {
  final String id;
  final String displayName;
  final DateTime? birthDate;

  /// Edad ya calculada por el backend — presente en el lado `otherUser`
  /// de `/matches` (que, como `/discover`, no manda `birthDate` exacto
  /// por privacidad). Cuando esto viene seteado tiene prioridad sobre
  /// calcular la edad a partir de `birthDate`.
  final int? _explicitAge;

  final String? city;
  final String? bio;
  final List<String> photos;
  final List<Sport> sports;

  /// Ubicación elegida a mano (Hinge-style), null hasta que el usuario la
  /// setea. Solo viene en el propio perfil (`/me`) — nunca en el de otros
  /// usuarios, por privacidad (igual que `birthDate` exacto).
  final double? latitude;
  final double? longitude;

  Profile({
    required this.id,
    required this.displayName,
    required this.photos,
    required this.sports,
    this.birthDate,
    int? age,
    this.city,
    this.bio,
    this.latitude,
    this.longitude,
  }) : _explicitAge = age;

  int? get age {
    if (_explicitAge != null) return _explicitAge;
    if (birthDate == null) return null;
    final now = DateTime.now();
    int a = now.year - birthDate!.year;
    final hadBirthday =
        (now.month > birthDate!.month) ||
        (now.month == birthDate!.month && now.day >= birthDate!.day);
    if (!hadBirthday) a--;
    return a;
  }

  String? get mainPhoto => photos.isNotEmpty ? photos.first : null;

  bool get hasLocation => latitude != null && longitude != null;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.tryParse(json['birthDate'].toString()),
      age: json['age'] is int ? json['age'] as int : null,
      city: json['city']?.toString(),
      bio: json['bio']?.toString(),
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      sports: (json['sports'] as List<dynamic>? ?? const [])
          .map((e) => SportApi.fromApi(e.toString()))
          .toList(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class Preferences {
  final int distanceKm;
  final int ageMin;
  final int ageMax;

  const Preferences({
    required this.distanceKm,
    required this.ageMin,
    required this.ageMax,
  });

  factory Preferences.fromJson(Map<String, dynamic> json) {
    return Preferences(
      distanceKm: (json['distanceKm'] as num?)?.toInt() ?? 25,
      ageMin: (json['ageMin'] as num?)?.toInt() ?? 18,
      ageMax: (json['ageMax'] as num?)?.toInt() ?? 60,
    );
  }
}

class MeResponse {
  final String id;
  final String email;
  final Profile? profile;
  final Preferences? preferences;

  MeResponse({
    required this.id,
    required this.email,
    required this.profile,
    this.preferences,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      id: json['id'] as String,
      email: (json['email'] ?? '') as String,
      profile: json['profile'] == null
          ? null
          : Profile.fromJson(json['profile'] as Map<String, dynamic>),
      preferences: json['preferences'] == null
          ? null
          : Preferences.fromJson(json['preferences'] as Map<String, dynamic>),
    );
  }
}
