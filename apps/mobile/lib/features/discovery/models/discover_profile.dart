import 'skill_level.dart';
import 'sport.dart';

class DiscoverProfile {
  final String userId;
  final String displayName;
  final int age;
  final String? city;
  final String? bio;
  final List<String> photos;
  final List<Sport> sports;

  /// Señales de confianza + nivel auto-declarado — ver status.md,
  /// "Reposicionamiento de producto". Público, mismo nivel de visibilidad
  /// que `bio`/`sports` (no tan privado como la fecha de nacimiento).
  final int? yearsPlaying;
  final String? club;
  final List<String> achievements;
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;
  final Map<Sport, SkillLevel> skillLevels;

  DiscoverProfile({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.photos,
    required this.sports,
    this.city,
    this.bio,
    this.yearsPlaying,
    this.club,
    this.achievements = const [],
    this.avgPaceMinPerKm,
    this.avgDistanceKm,
    this.skillLevels = const {},
  });

  String? get mainPhoto => photos.isNotEmpty ? photos.first : null;

  factory DiscoverProfile.fromJson(Map<String, dynamic> json) {
    // Soporta dos formas comunes:
    // A) { userId, displayName, age, city, bio, photos, sports }
    // B) { userId, profile: { ... } }
    final Map<String, dynamic> p = (json['profile'] is Map<String, dynamic>)
        ? (json['profile'] as Map<String, dynamic>)
        : json;

    return DiscoverProfile(
      userId: (json['userId'] ?? p['userId'] ?? p['id']).toString(),
      displayName: (p['displayName'] ?? '').toString(),
      age: p['age'] is int ? p['age'] as int : int.parse(p['age'].toString()),
      city: p['city']?.toString(),
      bio: p['bio']?.toString(),
      photos: (p['photos'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      sports: (p['sports'] as List<dynamic>? ?? const [])
          .map((e) => SportApi.fromApi(e.toString()))
          .toList(),
      yearsPlaying: (p['yearsPlaying'] as num?)?.toInt(),
      club: p['club']?.toString(),
      achievements: (p['achievements'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      avgPaceMinPerKm: (p['avgPaceMinPerKm'] as num?)?.toDouble(),
      avgDistanceKm: (p['avgDistanceKm'] as num?)?.toDouble(),
      skillLevels: skillLevelsFromJson(p['skillLevels']),
    );
  }
}
