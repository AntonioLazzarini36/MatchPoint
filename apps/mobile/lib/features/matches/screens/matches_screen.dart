import 'package:flutter/material.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/ui/widgets/error_state_view.dart';
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

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// El mapa de clubes es exclusivo de tenis, asi que a quien solo corre
  /// no se le enseña: antes aparecia siempre, y desde el chat de un match
  /// de correr llevaba a una pantalla de pistas que no le sirve de nada.
  @override
  void initState() {
    super.initState();
    controller = MatchesController(MatchesService(Api.client));
    controller.init();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _query = '';
      }
    });
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
            title: _searching
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre...',
                      border: InputBorder.none,
                    ),
                  )
                : const Text('Mensajes'),
            actions: [
              // El acceso al mapa de clubes vivia aqui arriba, pero se
              // solapaba con el boton de proponer del chat (que ademas
              // lleva el club ya elegido) y en un perfil de los dos
              // deportes ensuciaba la pantalla con una raqueta que no
              // tenia nada que ver con la conversacion que estabas
              // mirando. Sigue accesible desde el propio chat de tenis.
              IconButton(
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: _toggleSearch,
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
      return ErrorStateView(
        error: controller.error!,
        onRetry: () async => controller.reload(),
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

    // El buscador solo filtra la lista de conversaciones, no "Nuevos
    // Matches" — buscar es para encontrar un chat existente, no para
    // esa fila.
    final filteredMatches = _query.isEmpty
        ? matches
        : matches
              .where(
                (m) => (m.otherUser.profile?.displayName ?? '')
                    .toLowerCase()
                    .contains(_query),
              )
              .toList();

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

        if (filteredMatches.isEmpty && _query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sin resultados para "$_query"',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),

        for (final m in filteredMatches)
          MatchChatItem(
            name: m.otherUser.profile?.displayName ?? 'Sin nombre',
            message: m.lastMessage?.text ?? 'Nuevo match',
            time: _formatTime(m.lastMessage?.createdAt ?? m.createdAt),
            imageUrl: (m.otherUser.profile?.photos.isNotEmpty ?? false)
                ? m.otherUser.profile!.photos.first
                : null,
            unread: m.unreadCount > 0,
            sport: m.sport,
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
