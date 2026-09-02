import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/app_sports.dart';
import '../../../utils/sport_words.dart';
import '../../profile/network_photo.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../features/discovery/models/skill_level.dart';
import '../../../../features/discovery/models/sport.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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

    // Quien ya te ha dado like tiene la tarjeta **entera** tenida, no un
    // borde de color. Antes era un filete lima con el aviso escrito tambien
    // en lima, y ese lima sobre blanco no se leia (ver `tertiaryContainer` en
    // el tema): el estado mas importante del feed —un toque tuyo y hay
    // partido— era justo el peor de ver.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      // Mismo rectángulo que las demás: sólo cambia el color de fondo. Llevó
      // además un borde oscuro, y sobraba — teñir el fondo ya separa la
      // tarjeta del resto, y el borde encima la sacaba de la cuadrícula.
      color: user.likesYou ? colors.tertiaryContainer : null,
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
                  // El corazón dice lo que antes ocupaba una frase entera
                  // ("Ya quiere jugar contigo — acepta y tenéis partido").
                  // Va **sobre la foto** y no suelto en la fila: pegado a la
                  // cara se entiende de quién habla sin leer nada, y no
                  // empuja al resto de datos.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          width: 84,
                          height: 63, // 16:9, como se guardan las fotos
                          child: photo == null
                              ? Container(color: colors.surfaceContainerHighest)
                              : NetworkPhoto(url: photo, iconSize: 24),
                        ),
                      ),
                      if (user.likesYou)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: colors.tertiary,
                              shape: BoxShape.circle,
                              // Un aro del color de la tarjeta, para que el
                              // círculo se despegue de la foto sea cual sea
                              // la foto — sin él, sobre una imagen clara
                              // desaparece.
                              border: Border.all(
                                color: colors.tertiaryContainer,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.favorite,
                              size: 13,
                              color: colors.onTertiary,
                            ),
                          ),
                        ),
                    ],
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
                                // **Siempre el nivel, nunca "Tu mismo
                                // nivel".** Esa frase gastaba la etiqueta
                                // entera en decir algo que el color ya dice,
                                // y a cambio escondía el dato: justo con la
                                // gente que mejor encaja contigo era
                                // imposible saber a qué nivel juega.
                                label: _level!.label,
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
                  // Sobre una tarjeta ya tenida de lima, el gris de "no
                  // coincidis" desaparece: se usa la superficie normal para
                  // que el bloque siga leyendose como un bloque aparte.
                  color: shared.isEmpty
                      ? (user.likesYou
                            ? colors.surface
                            : colors.surfaceContainerHighest)
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


              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: onDismiss,
                    child: Text(S.current.notNow),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onWantToPlay,
                    icon: const Icon(Icons.sports_tennis, size: 18),
                    label: Text(
                      user.likesYou ? S.current.playWith(_firstName) : S.current.iWantToPlay,
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
      km < 1
          ? S.current.lessThanOneKm
          : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  /// Siempre el número, nunca la lista de franjas.
  ///
  /// Antes, con tres o menos, se enumeraban ("Coincidís: mar noche · vie
  /// noche"), con la idea de que saber *cuáles* ayudaba más que saber
  /// cuántas. En la práctica se lee como un jeroglífico: tres abreviaturas
  /// pegadas que hay que descifrar una a una en una fila que se recorre de
  /// un vistazo. Y el detalle está a un toque, en el perfil, donde la
  /// rejilla lo enseña entero y bien.
  static String _sharedLabel(List<String> slots) {
    if (slots.isEmpty) {
      return S.current.noSharedSlots;
    }
    if (slots.length == 1) return S.current.oneSharedSlot;
    return S.current.sharedSlots(slots.length);
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
