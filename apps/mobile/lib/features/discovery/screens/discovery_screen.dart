import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../../../core/network/api.dart';
import '../discovery_controller.dart';
import '../models/discover_profile.dart';
import '../services/discovery_service.dart';
import 'package:match_point/features/discovery/models/swipe_type.dart';
import '../../../core/ui/widgets/discovery/discovery_match_dialog.dart';
import '../../../core/ui/widgets/discovery/discovery_mini_card.dart';
import '../../../core/ui/widgets/discovery/discovery_preview_sheet.dart';

/// Column of small horizontal-rectangle cards (up to 4, each an equal,
/// non-overlapping share of the available height) shown stacked instead of
/// the old one-at-a-time full-screen swipe deck. Each card is independently
/// draggable — drag it away to like/pass, tap it for a bigger preview. No
/// separate like/pass buttons: the drag *is* the action now, buttons would
/// be redundant.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  static const _maxVisible = 4;
  static const _cardSpacing = 10.0;

  late final DiscoveryController controller;

  @override
  void initState() {
    super.initState();
    controller = DiscoveryController(DiscoveryService(Api.client));
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleSwipe(DiscoverProfile user, SwipeType type) async {
    try {
      final res = await controller.swipeUser(user: user, type: type);

      if (!mounted) return;

      if (type == SwipeType.like && res.matched) {
        await showDiscoveryMatchDialog(
          context,
          user: res.user,
          matchId: res.matchId,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el swipe, reintenta')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top bar: solo el título y el acceso a filtros (deshabilitado
                // hasta que haya una UI de preferencias que editar, ver
                // status.md) — sin selector de deporte ni el toggle
                // "Partner"/"Match" que no hacía nada.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Descubrir', style: context.textStyles.titleLarge),
                      IconButton(
                        onPressed: () {
                          // TODO filtros (prefs)
                        },
                        icon: Icon(Icons.tune, color: context.colors.onSurface),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(
                'Error cargando perfiles',
                style: context.textStyles.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.reload,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.stack.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: context.colors.outline),
            const SizedBox(height: 16),
            Text(
              'No hay mas perfiles cerca',
              style: context.textStyles.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: controller.reload,
              child: const Text('Reiniciar busqueda'),
            ),
          ],
        ),
      );
    }

    final stack = controller.stack;
    final visible = stack.length <= _maxVisible
        ? stack
        : stack.sublist(stack.length - _maxVisible);

    // Non-overlapping, stacked in a Column with margin on every side — none
    // of them touch the screen edges or reach into the bottom nav below
    // Discovery, since this all lives inside the Expanded body area handed
    // to us by build(). Card height is fixed at "1/4 of the available
    // space" regardless of how many cards are actually left — so a card
    // never grows just because there are fewer of them; only how many rows
    // are stacked (and their position) changes as the deck empties out.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight =
              (constraints.maxHeight - _cardSpacing * (_maxVisible - 1)) /
              _maxVisible;
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: _cardSpacing),
                SizedBox(
                  height: cardHeight,
                  child: _buildCard(context, visible[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, DiscoverProfile user) {
    return Dismissible(
      // Includes `generation` so a card rolled back after a failed swipe
      // gets a fresh key instead of resurrecting the Dismissible that was
      // just dismissed — reusing that key crashes.
      key: ValueKey('${user.userId}_${controller.generation}'),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        final type = direction == DismissDirection.startToEnd
            ? SwipeType.like
            : SwipeType.pass;
        _handleSwipe(user, type);
      },
      background: _swipeOverlay(context, Alignment.centerLeft, Icons.favorite, Colors.green),
      secondaryBackground: _swipeOverlay(context, Alignment.centerRight, Icons.close, Colors.red),
      child: DiscoveryMiniCard(
        user: user,
        onTap: () => showDiscoveryPreviewSheet(context, user),
      ),
    );
  }

  /// "Difuminado" directional hint shown as the card is dragged — a
  /// translucent color wash across the whole card rather than a small
  /// badge, since these cards are too small for a badge to read clearly.
  Widget _swipeOverlay(
    BuildContext context,
    Alignment alignment,
    IconData icon,
    Color color,
  ) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
