import '../../../features/discovery/models/skill_level.dart';
import '../../../features/onboarding/models/availability.dart';
import '../../../features/onboarding/models/intention.dart';
import '../../../features/discovery/models/sport.dart';

class ProfileHeaderData {
  final String displayName;
  final int? age;
  final String? city;
  final String? bio;

  /// A qué viene. Se ensena como etiqueta junto a los deportes, no dentro
  /// de la bio: es un dato estructurado y meterlo en el texto libre es
  /// justo lo que hacia que todos los perfiles se leyeran igual.
  final Intention? intention;

  /// Horario semanal habitual. Vacío = no lo ha dicho.
  final WeeklyAvailability availability;
  final List<String> photos;
  final List<Sport> sports;

  /// Señales de confianza + nivel auto-declarado — ver status.md,
  /// "Reposicionamiento de producto".
  final Map<Sport, SkillLevel> skillLevels;
  final int? yearsPlaying;
  final String? club;
  final List<String> achievements;
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;

  const ProfileHeaderData({
    required this.displayName,
    required this.photos,
    required this.sports,
    this.age,
    this.city,
    this.bio,
    this.intention,
    this.availability = WeeklyAvailability.empty,
    this.skillLevels = const {},
    this.yearsPlaying,
    this.club,
    this.achievements = const [],
    this.avgPaceMinPerKm,
    this.avgDistanceKm,
  });

  String get title {
    final a = age;
    return a == null ? displayName : '$displayName, $a';
  }

  String get subtitle {
    final c = (city ?? '').trim();
    return c.isEmpty ? '—' : c;
  }

  String? get mainPhoto => photos.isNotEmpty ? photos.first : null;
}
