import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../app/routes.dart';

Future<void> showDiscoveryMatchDialog(
  BuildContext context, {
  required DiscoverProfile user,
  required String? matchId,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake, color: context.colors.primary, size: 80),
            const SizedBox(height: 16),
            Text(
              '¡Es un Match!',
              style: context.textStyles.displaySmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tú y ${user.displayName} podéis organizar un partido.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodyLarge,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Seguir buscando'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // Si tu chat necesita matchId, pasalo:
                      context.go(AppRoutes.chat, extra: {'matchId': matchId});
                    },
                    child: const Text('Enviar mensaje'),
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
