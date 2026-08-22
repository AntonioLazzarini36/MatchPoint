import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/date_format_es.dart';
import '../../../utils/sport_words.dart';
import '../../../../features/discovery/models/skill_level.dart';
import '../../../../features/discovery/models/sport.dart';
import '../../../../features/matches/models/match_item.dart';
import '../../../../features/matches/models/proposal.dart';
import '../../profile/network_photo.dart';

/// Una persona con la que has hecho match, en la lista de "Tus compañeros".
///
/// Sustituye a la fila de chat de antes, que era la de una app de mensajería:
/// cara redonda, fragmento del último mensaje y hora. Eso pone delante quién
/// escribió más recientemente, que es lo que importa en una bandeja de
/// entrada — pero aquí lo que importa es **si podéis jugar y cuándo**.
///
/// Por eso la línea principal es el estado de la quedada, y el deporte y el
/// nivel van como etiquetas: son la promesa de la app hecha visible. El chat
/// no desaparece (tocar la fila lo abre, y el contador de no leídos sigue
/// ahí), sólo deja de ser el titular.
class PartnerRow extends StatelessWidget {
  final MatchItem match;

  /// La quedada viva de este match, si la hay. Decide la línea de estado.
  final Proposal? session;

  /// Nivel declarado de la otra persona en el deporte del match.
  final SkillLevel? skillLevel;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PartnerRow({
    super.key,
    required this.match,
    required this.session,
    required this.skillLevel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final profile = match.otherUser.profile;
    final name = profile?.displayName ?? 'Sin nombre';
    final photo = (profile?.photos.isNotEmpty ?? false)
        ? profile!.photos.first
        : null;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cuadrado redondeado y no círculo: el círculo es la convención
            // de las apps sociales y de citas; esto se lee como ficha.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: photo == null
                    ? Container(
                        color: context.colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline,
                          color: context.colors.outline,
                        ),
                      )
                    : NetworkPhoto(url: photo, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (profile?.age != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${profile!.age}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (match.unreadCount > 0) _unreadBadge(context),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(
                        context,
                        match.sport.label,
                        sportAccent(match.sport),
                      ),
                      if (skillLevel != null)
                        _chip(
                          context,
                          skillLevel!.label,
                          context.colors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _stateLine(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La línea que responde "¿y qué hacemos?". Es lo único de la fila que
  /// cambia de color, porque es lo único que puede reclamar acción.
  Widget _stateLine(BuildContext context) {
    final s = session;

    if (s == null) {
      return Text(
        'Aún no habéis quedado',
        style: context.textStyles.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }

    final cuando = formatProposalDateTime(s.scheduledAt);
    final donde = s.placeName;

    if (s.status == ProposalStatus.accepted) {
      return _state(
        context,
        Icons.event_available,
        donde == null ? cuando : '$cuando · $donde',
        context.colors.primary,
        bold: true,
      );
    }

    if (s.isPending && !s.mine) {
      return _state(
        context,
        Icons.mark_email_unread_outlined,
        'Te propone $cuando',
        sportAccent(s.sport),
        bold: true,
      );
    }

    return _state(
      context,
      Icons.hourglass_empty,
      'Esperando su respuesta · $cuando',
      context.colors.onSurfaceVariant,
    );
  }

  Widget _state(
    BuildContext context,
    IconData icon,
    String text,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _unreadBadge(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '${match.unreadCount}',
        style: context.textStyles.labelSmall?.copyWith(
          color: context.colors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
