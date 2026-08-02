import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../features/discovery/models/skill_level.dart';
import '../../../../features/discovery/models/sport.dart';

/// Bigger read-only look at a profile, opened by tapping a mini card —
/// stays within Discovery (a modal, not a navigation) so you don't lose
/// your place in the row underneath. No like/pass buttons in here on
/// purpose: swiping the card itself is still the only way to act on it.
Future<void> showDiscoveryPreviewSheet(
  BuildContext context,
  DiscoverProfile user,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user.displayName}, ${user.age}',
                    style: context.textStyles.headlineSmall,
                  ),
                  if ((user.city ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        user.city!,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (user.sports.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sport in user.sports)
                            Chip(
                              label: Text(
                                user.skillLevels[sport] == null
                                    ? sport.label
                                    : '${sport.label} · ${user.skillLevels[sport]!.label}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  if ((user.bio ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        user.bio!,
                        style: context.textStyles.bodyLarge,
                      ),
                    ),
                  if (_hasCredentials(user))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _CredentialsSection(user: user),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _hasCredentials(DiscoverProfile user) {
  return user.yearsPlaying != null ||
      (user.club ?? '').isNotEmpty ||
      user.achievements.isNotEmpty;
}

/// Señales de confianza estructuradas ("ha jugado estos torneos que
/// conozco") — ver status.md, "Reposicionamiento de producto". Separado
/// del bio libre a propósito, para que no dependa de que la persona se
/// acuerde de escribirlo ahí.
class _CredentialsSection extends StatelessWidget {
  final DiscoverProfile user;

  const _CredentialsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experiencia',
          style: context.textStyles.titleSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (user.yearsPlaying != null)
          _infoRow(context, Icons.timeline, '${user.yearsPlaying} años jugando'),
        if ((user.club ?? '').isNotEmpty)
          _infoRow(context, Icons.groups_outlined, user.club!),
        for (final achievement in user.achievements)
          _infoRow(context, Icons.emoji_events_outlined, achievement),
      ],
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Padding(
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
    );
  }
}
