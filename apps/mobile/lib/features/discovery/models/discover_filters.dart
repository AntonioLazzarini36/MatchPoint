import 'package:match_point/features/onboarding/models/availability.dart';

import 'skill_level.dart';

/// Lo que se le pregunta al feed: **cuándo** puedes jugar y, si quieres,
/// contra qué nivel.
///
/// Es el cambio de producto entero resumido en una clase. Antes la pantalla
/// de buscar no preguntaba nada: enseñaba caras por orden y tú decidías por
/// la foto. Ahora la pregunta va primero — "¿quién puede el sábado por la
/// mañana?" — y las caras son la respuesta, no el criterio.
class DiscoverFilters {
  /// Los huecos en los que *tú* quieres jugar, como el mismo mapa de bits de
  /// 21 posiciones del horario semanal. Vacío = sin filtrar por horario.
  final WeeklyAvailability when;

  /// Sólo gente de este nivel. `null` = cualquiera.
  final SkillLevel? level;

  const DiscoverFilters({
    this.when = WeeklyAvailability.empty,
    this.level,
  });

  static const none = DiscoverFilters();

  bool get isEmpty => when.isEmpty && level == null;
  bool get isNotEmpty => !isEmpty;

  /// Cuántos filtros hay puestos. Es lo que decide si el botón lleva chapa
  /// y qué ofrecer cuando el resultado sale vacío.
  int get activeCount => (when.isEmpty ? 0 : 1) + (level == null ? 0 : 1);

  DiscoverFilters copyWith({
    WeeklyAvailability? when,
    SkillLevel? level,
    bool clearLevel = false,
  }) {
    return DiscoverFilters(
      when: when ?? this.when,
      level: clearLevel ? null : (level ?? this.level),
    );
  }

  /// Los parámetros de query tal cual los espera `/discover`. Se omiten los
  /// que no aportan: una máscara a 0 en la URL sería ruido, y el backend ya
  /// la trata como "sin filtro" de todas formas.
  Map<String, String> toQuery() => {
    if (when.isNotEmpty) 'availability': when.mask.toString(),
    if (level != null) 'level': level!.apiValue,
  };
}
