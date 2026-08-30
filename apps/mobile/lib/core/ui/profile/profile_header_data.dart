import '../../../features/discovery/models/level_verdict.dart';
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

  /// Los huecos en los que coincidís, para destacarlos dentro de [availability].
  /// Vacío en el perfil propio: ahí no hay con quién cruzarlo.
  final WeeklyAvailability sharedAvailability;

  /// Qué opina de su nivel quien ha jugado con esta persona. `null` mientras
  /// nadie lo haya valorado — la fila entera desaparece, en vez de decir "0
  /// valoraciones", que suena a que alguien miró y no opinó.
  final LevelVerdict? levelVerdict;
  final int levelVotes;

  /// Si esta ficha es la tuya, para redactar en segunda persona.
  final bool isMine;
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
    this.sharedAvailability = WeeklyAvailability.empty,
    this.levelVerdict,
    this.levelVotes = 0,
    this.isMine = false,
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

  /// El veredicto llega después que el resto del perfil (es otra llamada), y
  /// rehacer el `ProfileHeaderData` entero a mano en el sitio donde llega
  /// sería copiar quince campos y olvidarse de uno al añadir el dieciséis.
  ProfileHeaderData copyWithVerdict(LevelVerdict? verdict, int votes) =>
      ProfileHeaderData(
        displayName: displayName,
        age: age,
        city: city,
        bio: bio,
        intention: intention,
        availability: availability,
        sharedAvailability: sharedAvailability,
        levelVerdict: verdict,
        levelVotes: votes,
        isMine: isMine,
        photos: photos,
        sports: sports,
        skillLevels: skillLevels,
        yearsPlaying: yearsPlaying,
        club: club,
        achievements: achievements,
        avgPaceMinPerKm: avgPaceMinPerKm,
        avgDistanceKm: avgDistanceKm,
      );
}
