import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/landscape_crop.dart';
import '../../../utils/pace_format.dart';
import '../../../utils/sport_words.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../features/discovery/models/skill_level.dart';
import '../../../../features/discovery/models/sport.dart';
import 'discovery_mini_card.dart' show distanceLabel;

/// Vista ampliada de un perfil, al tocar su tarjeta. Es un modal y no una
/// navegación a propósito: así no pierdes el sitio en la columna de abajo.
/// Sin botones de like/pass aquí dentro tampoco a propósito — arrastrar la
/// tarjeta sigue siendo la única forma de decidir.
Future<void> showDiscoveryPreviewSheet(
  BuildContext context,
  DiscoverProfile user,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) =>
          _PreviewBody(user: user, scrollController: scrollController),
    ),
  );
}

class _PreviewBody extends StatelessWidget {
  final DiscoverProfile user;
  final ScrollController scrollController;

  const _PreviewBody({required this.user, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.likesYou || user.matchesYourLevel) ...[
                  _callout(context),
                  const SizedBox(height: 16),
                ],
                _sportsRow(context),
                if ((user.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Sobre', style: context.textStyles.titleSmall),
                  const SizedBox(height: 6),
                  Text(user.bio!, style: context.textStyles.bodyLarge),
                ],
                if (_hasCredentials) ...[
                  const SizedBox(height: 18),
                  Text('Experiencia', style: context.textStyles.titleSmall),
                  const SizedBox(height: 8),
                  ..._credentialRows(context),
                ],
                // El resto de fotos, en vertical: antes sólo se veía la
                // primera y las demás no tenían ningún sitio donde
                // aparecer dentro de la preview.
                for (final photo in user.photos.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: AspectRatio(
                        aspectRatio: kPhotoAspectRatio,
                        child: Image.network(photo, fit: BoxFit.cover),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Foto grande con el nombre encima, en vez de foto y debajo un bloque de
  /// texto suelto: es lo que hace que se lea como un perfil y no como una
  /// ficha de datos.
  Widget _hero(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: kPhotoAspectRatio,
          child: user.mainPhoto != null
              ? Image.network(user.mainPhoto!, fit: BoxFit.cover)
              : Container(
                  color: context.colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.person,
                    size: 64,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${user.displayName}, ${user.age}',
                style: context.textStyles.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if ((user.city ?? '').isNotEmpty) user.city!.split(',').first,
                  if (user.distanceKm != null) distanceLabel(user.distanceKm!),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// El motivo por el que este perfil está destacado, dicho con palabras.
  /// El borde de color en la tarjeta llama la atención, pero no explica
  /// nada; aquí es donde se justifica.
  Widget _callout(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, icon, title, detail) = user.likesYou
        ? (
            colors.tertiaryContainer,
            colors.onTertiaryContainer,
            Icons.bolt,
            'Ya te ha dado like',
            'Si tú también quieres jugar, hacéis match al instante.',
          )
        : (
            colors.primaryContainer,
            colors.onPrimaryContainer,
            Icons.equalizer,
            'Juega a tu nivel',
            'Mismo nivel declarado que el tuyo en el deporte que estás '
                'mirando.',
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Deporte + nivel como tarjetas y no como chips sueltos: es el dato por
  /// el que se entra a mirar un perfil, así que merece más peso visual que
  /// el resto.
  Widget _sportsRow(BuildContext context) {
    if (user.sports.isEmpty) {
      return Text(
        'No ha dicho a qué juega.',
        style: context.textStyles.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }

    return Row(
      children: [
        for (final sport in user.sports) ...[
          Expanded(child: _sportCard(context, sport)),
          if (sport != user.sports.last) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _sportCard(BuildContext context, Sport sport) {
    final colors = context.colors;
    final level = user.skillLevels[sport];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(sportIcon(sport), color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sport.label, style: context.textStyles.titleSmall),
                Text(
                  level?.label ?? 'Sin nivel',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasCredentials =>
      user.yearsPlaying != null ||
      (user.club ?? '').isNotEmpty ||
      user.avgPaceMinPerKm != null ||
      user.avgDistanceKm != null ||
      user.achievements.isNotEmpty;

  /// Señales de confianza estructuradas ("ha jugado estos torneos que
  /// conozco") — ver status.md, "Reposicionamiento de producto". Separado
  /// del bio libre a propósito, para que no dependa de que la persona se
  /// acuerde de escribirlo ahí.
  List<Widget> _credentialRows(BuildContext context) {
    final rows = <(IconData, String)>[
      if (user.yearsPlaying != null)
        (Icons.timeline, '${user.yearsPlaying} años jugando'),
      if ((user.club ?? '').isNotEmpty) (Icons.groups_outlined, user.club!),
      if (user.avgPaceMinPerKm != null)
        (
          Icons.speed,
          'Ritmo medio: ${formatPaceMinPerKm(user.avgPaceMinPerKm)} min/km',
        ),
      if (user.avgDistanceKm != null)
        (Icons.route, 'Distancia media: ${user.avgDistanceKm} km'),
      for (final achievement in user.achievements)
        (Icons.emoji_events_outlined, achievement),
    ];

    return [
      for (final (icon, text) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: context.textStyles.bodyMedium),
              ),
            ],
          ),
        ),
    ];
  }
}
