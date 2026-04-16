import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:match_point/app/routes.dart';

import '../../../core/network/api.dart';
import '../discovery_controller.dart';
import '../services/discovery_service.dart';
import 'package:match_point/features/discovery/models/swipe_type.dart';
import '../../../core/ui/widgets/discovery/discovery_sport_toggle.dart';
import '../../../core/ui/widgets/discovery/discovery_mode_toggle.dart';
import '../../../core/ui/widgets/discovery/discovery_action_button.dart';
import '../../../core/ui/widgets/discovery/discovery_match_dialog.dart';
import '../../../core/ui/widgets/discovery/discovery_swipe_card.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DiscoverySportToggle(
                        selected: controller.selectedSport,
                        onChanged: controller.setSport,
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO filtros (prefs)
                        },
                        icon: Icon(Icons.tune, color: context.colors.onSurface),
                      ),
                    ],
                  ),
                ),

                // Mode toggle
                DiscoveryModeToggle(
                  isPartnerMode: controller.isPartnerMode,
                  onChanged: controller.setMode,
                ),

                const SizedBox(height: 16),

                Expanded(child: _buildBody(context)),

                if (controller.stack.isNotEmpty) _buildActions(context),

                const SizedBox(height: 16),
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
              'No hay más perfiles cerca',
              style: context.textStyles.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: controller.reload,
              child: const Text('Reiniciar búsqueda'),
            ),
          ],
        ),
      );
    }

    // Deck
    final stack = controller.stack;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Stack(
        children: stack.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          final isTop = index == stack.length - 1;

          if (!isTop) {
            return Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20.0 * (stack.length - 1 - index),
                  bottom: 20,
                ),
                child: Transform.scale(
                  scale: 0.95,
                  child: Opacity(
                    opacity: 0.5,
                    child: DiscoverySwipeCard(user: user, isFront: false),
                  ),
                ),
              ),
            );
          }

          return Dismissible(
            key: Key(user.userId),
            direction: DismissDirection.horizontal,
            onDismissed: (direction) async {
              final type = (direction == DismissDirection.startToEnd)
                  ? SwipeType.like
                  : SwipeType.pass;

              final res = await controller.swipeUser(user: user, type: type);

              if (!context.mounted) return;

              if (type == SwipeType.like && res.matched) {
                await showDiscoveryMatchDialog(
                  context,
                  user: res.user,
                  matchId: res.matchId,
                );
              }
            },
            background: _swipeBg(
              context,
              Alignment.centerLeft,
              Icons.favorite,
              Colors.green,
            ),
            secondaryBackground: _swipeBg(
              context,
              Alignment.centerRight,
              Icons.close,
              Colors.red,
            ),
            child: DiscoverySwipeCard(
              user: user, 
              isFront: true, 
              onOpenProfile: () {
                context.pushNamed(
                  AppRoutes.userProfileName,
                  pathParameters: {'userId': user.userId},
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          DiscoveryActionButton(
            icon: Icons.close,
            color: Colors.red,
            onTap: () => controller.passTop(),
          ),
          DiscoveryActionButton(
            icon: Icons.star,
            color: Colors.amber,
            onTap: () {
              // TODO super-like si lo añades en backend
            },
          ),
          DiscoveryActionButton(
            icon: Icons.favorite,
            color: context.colors.primary,
            onTap: () async {
              final res = await controller.likeTop();

              if (!context.mounted) return;

              if (res.matched && res.user != null) {
                await showDiscoveryMatchDialog(
                  context,
                  user: res.user!,
                  matchId: res.matchId,
                );
              } else if (res.user != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Has dado like a ${res.user!.displayName}!'),
                    duration: const Duration(milliseconds: 600),
                    backgroundColor: context.colors.tertiary,
                  ),
                );
              }
            },
          )
        ],
      ),
    );
  }

  Widget _swipeBg(
    BuildContext context,
    Alignment alignment,
    IconData icon,
    Color color,
  ) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
