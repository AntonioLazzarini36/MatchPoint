import 'package:match_point/features/discovery/models/skill_level.dart';
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

  /// Señales de confianza estructuradas ("che, este juega a mi nivel, ha
  /// jugado estos torneos") — ver status.md, "Reposicionamiento de
  /// producto". El nivel de habilidad NO vive acá — es un campo hermano
  /// de `profile` en `/me` (ver `MeResponse.skillLevels`), no anidado
  /// dentro del propio perfil.
  final int? yearsPlaying;
  final String? club;
  final List<String> achievements;

  /// Running-oriented counterpart to `yearsPlaying`/`club` — see
  /// `models::Profile` docs on the backend.
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;

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
    this.yearsPlaying,
    this.club,
    this.achievements = const [],
    this.avgPaceMinPerKm,
    this.avgDistanceKm,
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
      yearsPlaying: (json['yearsPlaying'] as num?)?.toInt(),
      club: json['club']?.toString(),
      achievements: (json['achievements'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble(),
      avgDistanceKm: (json['avgDistanceKm'] as num?)?.toDouble(),
    );
  }
}

class Preferences {
  final int distanceKm;
  final int ageMin;
  final int ageMax;

  /// Deportes que quiere ver en Discovery — independiente de
  /// `Profile.sports` (los que juega). Sin efecto todavia en el filtro de
  /// `/discover` (que sigue usando `Profile.sports` del propio usuario, ver
  /// discovery_controller.dart) - se guarda ya para poder usarlo mas
  /// adelante sin tener que volver a pedir el dato.
  final List<Sport> sportsWanted;

  /// Texto libre en el backend (`Preferences.genderPreference`, sin enum
  /// todavia) - null significa "cualquiera". Mismo caso que arriba: se
  /// guarda para uso futuro, `/discover` todavia no filtra por esto (no
  /// hay campo de genero en `Profile` para comparar contra).
  final String? genderPreference;

  const Preferences({
    required this.distanceKm,
    required this.ageMin,
    required this.ageMax,
    this.sportsWanted = const [],
    this.genderPreference,
  });

  factory Preferences.fromJson(Map<String, dynamic> json) {
    return Preferences(
      distanceKm: (json['distanceKm'] as num?)?.toInt() ?? 25,
      ageMin: (json['ageMin'] as num?)?.toInt() ?? 18,
      ageMax: (json['ageMax'] as num?)?.toInt() ?? 60,
      sportsWanted: (json['sportsWanted'] as List<dynamic>? ?? const [])
          .map((e) => SportApi.fromApi(e.toString()))
          .toList(),
      genderPreference: json['genderPreference']?.toString(),
    );
  }
}

class MeResponse {
  final String id;
  final String email;
  final Profile? profile;
  final Preferences? preferences;

  /// Hermano de `profile`, no anidado en él — el backend lo guarda en su
  /// propia tabla (una fila por deporte), ver
  /// `services/api-rust/src/me/service.rs::MeResponse`.
  final Map<Sport, SkillLevel> skillLevels;

  MeResponse({
    required this.id,
    required this.email,
    required this.profile,
    this.preferences,
    this.skillLevels = const {},
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
      skillLevels: skillLevelsFromJson(json['skillLevels']),
    );
  }
}
