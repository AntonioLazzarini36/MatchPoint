import 'package:flutter/material.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../matches_controller.dart';
import '../services/matches_service.dart';
import '../../../core/ui/widgets/matches/matches_section_title.dart';
import '../../../core/ui/widgets/matches/new_match_avatar_item.dart';
import '../../../core/ui/widgets/matches/match_chat_item.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late final MatchesController controller;

  @override
  void initState() {
    super.initState();
    controller = MatchesController(MatchesService(Api.client));
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
      builder: (_, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mensajes'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {}, // TODO
              ),
            ],
          ),
          body: _buildBody(context),
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
                'Error cargando matches',
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

    final matches = controller.matches;

    if (matches.isEmpty) {
      return Center(
        child: Text(
          'No tienes matches todavía',
          style: context.textStyles.titleMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    // “Nuevos matches” (horizontal): los 12 más recientes
    final newMatches = matches.take(12).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MatchesSectionTitle('Nuevos Matches'),
        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final m in newMatches)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: NewMatchAvatarItem(
                    name: m.otherUser.profile?.displayName ?? 'Sin nombre',
                    imageUrl: (m.otherUser.profile?.photos.isNotEmpty ?? false)
                        ? m.otherUser.profile!.photos.first
                        : null,
                    onTap: () {
                      context.push('/chat/${m.matchId}', extra: m);
                    },
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const MatchesSectionTitle('Mensajes'),
        const SizedBox(height: 12),

        for (final m in matches)
          MatchChatItem(
            name: m.otherUser.profile?.displayName ?? 'Sin nombre',
            message: 'Nuevo match',
            time: _formatTime(m.createdAt),
            imageUrl: (m.otherUser.profile?.photos.isNotEmpty ?? false)
                ? m.otherUser.profile!.photos.first
                : null,
            unread: false,
            isGroup: false,
            onTap: () {
              context.push('/chat/${m.matchId}', extra: m);
            },
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (sameDay) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd/$mo';
  }
}
