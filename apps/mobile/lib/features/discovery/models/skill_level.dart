import 'sport.dart';

/// Self-reported, not computed — there's no Elo/Glicko rating yet (see
/// status.md). One of these exists per sport a user plays, not a single
/// overall level, since someone can be advanced at tennis and a beginner
/// runner.
enum SkillLevel { beginner, intermediate, advanced, competitive }

extension SkillLevelApi on SkillLevel {
  String get apiValue {
    switch (this) {
      case SkillLevel.beginner:
        return 'BEGINNER';
      case SkillLevel.intermediate:
        return 'INTERMEDIATE';
      case SkillLevel.advanced:
        return 'ADVANCED';
      case SkillLevel.competitive:
        return 'COMPETITIVE';
    }
  }

  String get label {
    switch (this) {
      case SkillLevel.beginner:
        return 'Principiante';
      case SkillLevel.intermediate:
        return 'Intermedio';
      case SkillLevel.advanced:
        return 'Avanzado';
      case SkillLevel.competitive:
        return 'Competitivo';
    }
  }

  static SkillLevel fromApi(String v) {
    switch (v) {
      case 'BEGINNER':
        return SkillLevel.beginner;
      case 'INTERMEDIATE':
        return SkillLevel.intermediate;
      case 'ADVANCED':
        return SkillLevel.advanced;
      case 'COMPETITIVE':
        return SkillLevel.competitive;
      default:
        return SkillLevel.beginner;
    }
  }
}

/// Parses the backend's `[{sport, level}]` shape (one entry per sport)
/// into a lookup map — every screen that shows/edits a level looks it up
/// by sport, so the map is more useful than the raw list.
Map<Sport, SkillLevel> skillLevelsFromJson(dynamic json) {
  final list = json is List<dynamic> ? json : const <dynamic>[];
  final map = <Sport, SkillLevel>{};
  for (final entry in list) {
    if (entry is! Map<String, dynamic>) continue;
    final sport = entry['sport']?.toString();
    final level = entry['level']?.toString();
    if (sport == null || level == null) continue;
    map[SportApi.fromApi(sport)] = SkillLevelApi.fromApi(level);
  }
  return map;
}

/// Inverse of `skillLevelsFromJson`, for `PATCH /me/skill-levels`.
List<Map<String, String>> skillLevelsToJson(Map<Sport, SkillLevel> levels) {
  return levels.entries
      .map((e) => {'sport': e.key.apiValue, 'level': e.value.apiValue})
      .toList();
}
