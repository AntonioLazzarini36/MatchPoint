import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/discover_profile.dart';
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
                        children: [
                          for (final sport in user.sports)
                            Chip(label: Text(sport.label)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
