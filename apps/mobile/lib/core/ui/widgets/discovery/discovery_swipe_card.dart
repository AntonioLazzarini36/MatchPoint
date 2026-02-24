import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/discover_profile.dart';

class DiscoverySwipeCard extends StatelessWidget {
  final DiscoverProfile user;
  final bool isFront;
  final VoidCallback? onOpenProfile;

  const DiscoverySwipeCard({
    super.key,
    required this.user,
    required this.isFront,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isFront
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (user.mainPhoto != null)
              Image.network(user.mainPhoto!, fit: BoxFit.cover)
            else
              Container(color: context.colors.surfaceContainerHighest),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.displayName}, ${user.age}',
                        style: context.textStyles.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((user.city ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user.city!,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      if ((user.bio ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            user.bio!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
