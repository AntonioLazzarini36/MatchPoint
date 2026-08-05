import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/sport_words.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../features/discovery/models/skill_level.dart';
import '../../../../features/discovery/models/sport.dart';

/// Tarjeta de Discovery.
///
/// Antes era una miniatura con el nombre en `labelMedium` abajo a la
/// izquierda y poco más: a ese tamaño no se leía y, sobre todo, no decía
/// nada que ayudara a decidir. Ahora contesta las tres preguntas que
/// llevan a arrastrarla o no — **a qué juega y a qué nivel**, **a qué
/// distancia** y **si ya te ha dado like** — que es justo lo que la app
/// promete resolver (ver "Reposicionamiento de producto" en status.md).
class DiscoveryMiniCard extends StatelessWidget {
  final DiscoverProfile user;
  final VoidCallback? onTap;

  const DiscoveryMiniCard({super.key, required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highlighted = user.likesYou || user.matchesYourLevel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Material(
        color: colors.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (user.mainPhoto != null)
                Image.network(
                  user.mainPhoto!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _photoFallback(context),
                )
              else
                _photoFallback(context),

              // Marca de agua del deporte: da identidad a la tarjeta y
              // dice de un vistazo si esta persona es de tenis o de correr
              // sin gastar sitio en texto.
              Positioned(
                right: -18,
                top: -10,
                child: Icon(
                  sportIcon(_primarySport),
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),

              // Degradado sólo abajo: el texto tiene que leerse sobre
              // cualquier foto, pero tapar la foto entera la desperdicia.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),

              if (highlighted)
                Positioned(top: 10, left: 10, child: _highlightBadge(context)),

              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user.displayName}, ${user.age}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final sport in user.sports.take(2))
                          _pill(
                            context,
                            icon: sportIcon(sport),
                            label: user.skillLevels[sport] == null
                                ? sport.label
                                : user.skillLevels[sport]!.label,
                          ),
                        if (user.distanceKm != null)
                          _pill(
                            context,
                            icon: Icons.near_me_outlined,
                            label: distanceLabel(user.distanceKm!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Borde de acento por encima de todo, para que se vea
              // también sobre la parte clara de la foto.
              if (highlighted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: user.likesYou
                              ? colors.tertiary
                              : colors.primary,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Sport get _primarySport =>
      user.sports.isEmpty ? Sport.tennis : user.sports.first;

  Widget _photoFallback(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 48,
        color: context.colors.onSurfaceVariant,
      ),
    );
  }

  /// "Te ha dado like" gana a "A tu nivel": es lo más accionable de las
  /// dos, porque un like tuyo cierra el match ahí mismo.
  Widget _highlightBadge(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, icon, label) = user.likesYou
        ? (colors.tertiary, colors.onTertiary, Icons.bolt, 'Te ha dado like')
        : (colors.primary, colors.onPrimary, Icons.equalizer, 'A tu nivel');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Por debajo de 1 km el decimal es ruido ("a 0,4 km" no cambia ninguna
/// decisión); por encima, un entero basta. Compartido con el preview para
/// que la misma persona no salga "a 3 km" en un sitio y "a 2,8 km" en otro.
String distanceLabel(double km) => km < 1 ? 'Muy cerca' : 'A ${km.round()} km';
