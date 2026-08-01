import 'package:flutter/material.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../matches_controller.dart';
import '../models/match_item.dart';
import '../services/matches_service.dart';
import '../../../core/ui/dialogs/confirm_dialog.dart';
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

  /// Siempre recarga al volver del chat: entrar marca los mensajes como
  /// leídos (best-effort, ver ChatController.init), así que el preview/
  /// unread de la lista queda desactualizado incluso si no hubo unmatch.
  Future<void> _openChat(MatchItem m) async {
    await context.push<bool>('/chat/${m.matchId}', extra: m);
    controller.reload();
  }

  Future<void> _confirmUnmatch(MatchItem m) async {
    final name = m.otherUser.profile?.displayName ?? 'esta persona';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Deshacer match',
      content:
          '¿Seguro que quieres deshacer el match con $name? Se borrará '
          'también la conversación, y no se puede deshacer.',
      confirmLabel: 'Deshacer match',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await controller.service.unmatch(m.matchId);
      controller.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo deshacer: $e')));
    }
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
          'No tienes matches todavia',
          style: context.textStyles.titleMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    // “Nuevos matches” (horizontal): los 12 mas recientes
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
                    onTap: () => _openChat(m),
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
            message: m.lastMessage?.text ?? 'Nuevo match',
            time: _formatTime(m.lastMessage?.createdAt ?? m.createdAt),
            imageUrl: (m.otherUser.profile?.photos.isNotEmpty ?? false)
                ? m.otherUser.profile!.photos.first
                : null,
            unread: m.unreadCount > 0,
            isGroup: false,
            onTap: () => _openChat(m),
            onLongPress: () => _confirmUnmatch(m),
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
