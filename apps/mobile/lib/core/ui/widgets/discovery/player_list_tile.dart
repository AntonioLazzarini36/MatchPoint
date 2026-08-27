import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/app_sports.dart';
import '../../../utils/sport_words.dart';
import '../../profile/network_photo.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../features/discovery/models/skill_level.dart';
import '../../../../features/discovery/models/sport.dart';

/// Una persona, como una fila de una lista que se recorre — no como una
/// carta que se arrastra.
///
/// La diferencia no es de forma, es de qué decide. En el mazo lo primero
/// (y casi lo único) era la foto a media pantalla; aquí lo primero es
/// **cuándo coincidís**, luego el nivel y la distancia, y la foto es una
/// miniatura que confirma que hay una persona detrás. Sigue estando porque
/// vas a quedar con un desconocido y quieres verle la cara, pero ha dejado
/// de ser el criterio.
///
/// Las dos acciones son explícitas y no un gesto: en una lista que se
/// desplaza con el pulgar, arrastrar a los lados compite con el scroll, y
/// "quiero jugar" merece un botón con su nombre escrito.
class PlayerListTile extends StatelessWidget {
  final DiscoverProfile user;

  /// Nivel del que mira, para poder decir "tu mismo nivel" en vez de sólo
  /// el nombre del nivel del otro. `null` si no lo ha declarado.
  final SkillLevel? myLevel;

  final VoidCallback onTap;
  final VoidCallback onWantToPlay;
  final VoidCallback onDismiss;

  const PlayerListTile({
    super.key,
    required this.user,
    required this.myLevel,
    required this.onTap,
    required this.onWantToPlay,
    required this.onDismiss,
  });

  SkillLevel? get _level {
    final sport = singleSport;
    if (sport != null) return user.skillLevels[sport];
    return user.skillLevels.values.isEmpty
        ? null
        : user.skillLevels.values.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = context.textStyles;
    final photo = user.mainPhoto;
    final shared = user.sharedAvailability;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: user.likesYou ? colors.tertiary : colors.outlineVariant,
          width: user.likesYou ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      width: 84,
                      height: 63, // 16:9, como se guardan todas las fotos
                      child: photo == null
                          ? Container(color: colors.surfaceContainerHighest)
                          : NetworkPhoto(url: photo, iconSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.displayName}, ${user.age}',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_level != null)
                              _Tag(
                                icon: Icons.workspace_premium_outlined,
                                label: _level == myLevel
                                    ? 'Tu mismo nivel'
                                    : _level!.label,
                                // Con nivel igual deja de ser una etiqueta
                                // más y pasa a ser una chapa con fondo: en
                                // una fila con tres datos grises, poner el
                                // que decide el partido en negrita no basta
                                // para que salte a la vista.
                                badge: _level == myLevel,
                              ),
                            if (user.distanceKm != null)
                              _Tag(
                                icon: Icons.place_outlined,
                                label: _distanceLabel(user.distanceKm!),
                              ),
                            // El deporte sólo se dice cuando hay más de uno
                            // que decir: en una app de tenis, una etiqueta
                            // "Tenis" en cada fila no distingue nada.
                            if (!isSingleSportApp)
                              for (final sport in user.sports)
                                _Tag(
                                  icon: sportIcon(sport),
                                  label: sport.label,
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // La línea que justifica la pantalla entera: no "qué tal se
              // te ve", sino "podéis quedar, y estas son las franjas".
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: shared.isEmpty
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      shared.isEmpty
                          ? Icons.help_outline
                          : Icons.event_available,
                      size: 16,
                      color: shared.isEmpty
                          ? colors.onSurfaceVariant
                          : colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sharedLabel(shared.slotLabels),
                        style: t.bodySmall?.copyWith(
                          color: shared.isEmpty
                              ? colors.onSurfaceVariant
                              : colors.onPrimaryContainer,
                          fontWeight: shared.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (user.likesYou) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 15,
                      color: colors.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ya quiere jugar contigo — acepta y podéis hablar',
                      style: t.labelMedium?.copyWith(color: colors.tertiary),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Ahora no'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onWantToPlay,
                    icon: const Icon(Icons.sports_tennis, size: 18),
                    label: Text(
                      user.likesYou ? 'Jugar con $_firstName' : 'Quiero jugar',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _firstName => user.displayName.split(' ').first;

  static String _distanceLabel(double km) =>
      km < 1 ? 'menos de 1 km' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  /// Con más de tres franjas en común la frase se vuelve ilegible y el
  /// número dice lo mismo mejor.
  static String _sharedLabel(List<String> slots) {
    if (slots.isEmpty) {
      return 'No coincidís en ninguna franja de las que soléis tener libres';
    }
    if (slots.length <= 3) return 'Coincidís: ${slots.join(' · ')}';
    return 'Coincidís en ${slots.length} franjas horarias';
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Chapa con fondo en vez de texto suelto. Se reserva para lo que de
  /// verdad cambia la decisión — hoy, sólo "tu mismo nivel".
  final bool badge;

  const _Tag({required this.icon, required this.label, this.badge = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = badge ? colors.onPrimary : colors.onSurfaceVariant;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.textStyles.labelMedium?.copyWith(
            color: fg,
            fontWeight: badge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );

    if (!badge) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: content,
    );
  }
}
