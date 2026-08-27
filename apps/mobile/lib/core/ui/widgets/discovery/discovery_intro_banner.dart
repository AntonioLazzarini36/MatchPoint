import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Shown once, above the feed, the first time someone opens Discovery —
/// dumping straight into swipe cards with zero context was one of the
/// things called out in status.md ("Reposicionamiento de producto"). This
/// doesn't change the interaction, just explains it before the first
/// swipe instead of leaving people to guess.
class DiscoveryIntroBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const DiscoveryIntroBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sports_tennis, color: context.colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Empieza por cuándo puedes jugar',
                  style: context.textStyles.titleSmall?.withColor(
                    context.colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Marca las franjas en las que sueles tener libre y te ponemos '
                  'primero a quien coincide contigo. Toca a alguien para ver '
                  'su perfil, o dale a "Quiero jugar" y, si te lo devuelve, '
                  'ya podéis quedar.',
                  style: context.textStyles.bodySmall?.withColor(
                    context.colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: context.colors.onPrimaryContainer,
            ),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
