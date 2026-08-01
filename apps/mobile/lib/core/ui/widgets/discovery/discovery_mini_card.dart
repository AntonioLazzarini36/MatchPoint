import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/discover_profile.dart';

/// Compact card for the horizontal Discovery row — several of these show
/// at once (vs. the old one-at-a-time full-screen card), so this only
/// carries enough info to recognize someone at a glance; the rest shows
/// in the tap-to-preview sheet.
class DiscoveryMiniCard extends StatelessWidget {
  final DiscoverProfile user;
  final VoidCallback? onTap;

  const DiscoveryMiniCard({super.key, required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: context.colors.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (user.mainPhoto != null)
                Image.network(user.mainPhoto!, fit: BoxFit.cover)
              else
                Icon(
                  Icons.person,
                  size: 40,
                  color: context.colors.onSurfaceVariant,
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  '${user.displayName}, ${user.age}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
