import 'package:match_point/features/onboarding/models/availability.dart';
import 'package:match_point/features/onboarding/models/intention.dart';
import 'skill_level.dart';
import 'sport.dart';

class DiscoverProfile {
  final String userId;
  final String displayName;
  final int age;
  final String? city;
  final String? bio;

  /// A qué viene. Misma visibilidad que `bio`/`sports`: es la senal que
  /// hace decidir si merece la pena deslizar.
  final Intention? intention;
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

  /// Distancia en línea recta desde ti, en km. null cuando tú no tienes
  /// ubicación puesta — los perfiles sin ella ya no aparecen en Discovery.
  /// El backend nunca manda las coordenadas del otro, sólo esta cifra.
  final double? distanceKm;

  /// Horario semanal habitual. Se enseña al proponer, no filtra nada.
  final WeeklyAvailability availability;

  /// Su nivel declarado en el deporte que estás mirando coincide con el
  /// tuyo. Lo calcula el backend (ya lo necesita para ordenar el feed), así
  /// que el cliente no tiene que pedir sus propios niveles para deducirlo.
  final bool matchesYourLevel;

  /// Esta persona ya te dio like: darle like tú cierra el match al momento.
  final bool likesYou;

  /// Los huecos del horario en los que esta persona y tú coincidís. Lo
  /// calcula el backend (necesita los dos horarios, y el del otro no sale
  /// entero del servidor cruzado con el tuyo), y es lo primero que enseña
  /// la lista: es la respuesta a "¿podemos quedar de verdad?".
  final WeeklyAvailability sharedAvailability;

  /// Cuántos son. Viene hecho del backend porque además ordena el feed.
  final int sharedSlots;

  DiscoverProfile({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.photos,
    required this.sports,
    this.city,
    this.bio,
    this.intention,
    this.yearsPlaying,
    this.club,
    this.achievements = const [],
    this.avgPaceMinPerKm,
    this.avgDistanceKm,
    this.skillLevels = const {},
    this.distanceKm,
    this.availability = WeeklyAvailability.empty,
    this.matchesYourLevel = false,
    this.likesYou = false,
    this.sharedAvailability = WeeklyAvailability.empty,
    this.sharedSlots = 0,
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
      intention: IntentionApi.fromApi(p['intention']),
      availability: WeeklyAvailability.fromJson(p['availability']),
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
      distanceKm: (p['distanceKm'] as num?)?.toDouble(),
      matchesYourLevel: p['matchesYourLevel'] == true,
      likesYou: p['likesYou'] == true,
      sharedAvailability: WeeklyAvailability.fromJson(p['sharedAvailability']),
      sharedSlots: (p['sharedSlots'] as num?)?.toInt() ?? 0,
    );
  }
}
