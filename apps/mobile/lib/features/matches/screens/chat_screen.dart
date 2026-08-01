import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:match_point/app/routes.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../chat_controller.dart';
import '../services/chat_service.dart';
import '../services/matches_service.dart';
import '../../onboarding/services/profile_service.dart';

import '../../../core/ui/dialogs/confirm_dialog.dart';
import '../../../core/ui/dialogs/report_reason_dialog.dart';
import '../../../core/ui/widgets/chat/chat_message_bubble.dart';
import '../../../core/ui/widgets/chat/chat_input_bar.dart';

enum _ChatMenuAction { unmatch, report }

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String myUserId;
  final String otherUserId;
  final String otherName;
  final String? otherPhotoUrl;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.myUserId,
    required this.otherUserId,
    required this.otherName,
    this.otherPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController controller;
  late final MatchesService matchesService;
  late final ProfileService profileService;
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();

  bool _busy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    controller = ChatController(
      service: ChatService(Api.client),
      matchId: widget.matchId,
    );
    matchesService = MatchesService(Api.client);
    profileService = ProfileService(Api.client);
    controller.init().then((_) => _scrollToBottom());

    // No websocket/push here — short-interval polling is enough for this
    // app's scale, and far less machinery than standing up a socket.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final before = controller.messages.length;
      final wasNearBottom = _isNearBottom();
      await controller.pollNewMessages();
      if (!mounted) return;
      if (controller.messages.length > before && wasNearBottom) {
        _scrollToBottom();
      }
    });
  }

  bool _isNearBottom() {
    if (!scroll.hasClients) return true;
    const threshold = 120.0;
    return scroll.position.maxScrollExtent - scroll.position.pixels <
        threshold;
  }

  /// A diferencia de [_report], unmatch sí cierra el chat, devolviendo
  /// `true` para que `MatchesScreen` sepa que tiene que recargar la lista.
  Future<void> _unmatch() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Deshacer match',
      content:
          '¿Seguro que quieres deshacer este match? Se borrará también la '
          'conversación, y no se puede deshacer.',
      confirmLabel: 'Deshacer match',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await matchesService.unmatch(widget.matchId);
      if (!mounted) return;
      router.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _busy = false);
    }
  }

  /// Reportar no borra el match — a diferencia de unmatch, se queda en el
  /// chat en vez de cerrarlo.
  Future<void> _report() async {
    final reason = await showReportReasonDialog(context);
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await profileService.reportUser(widget.otherUserId, reason);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Reporte enviado')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return Scaffold(
          appBar: AppBar(
            title: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              context.pushNamed(
                AppRoutes.userProfileName,
                pathParameters: {'userId': widget.otherUserId},
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: context.colors.primaryContainer,
                  backgroundImage: widget.otherPhotoUrl == null
                      ? null
                      : NetworkImage(widget.otherPhotoUrl!),
                  child: widget.otherPhotoUrl == null
                      ? Icon(Icons.person, color: context.colors.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(widget.otherName, style: context.textStyles.titleMedium),
              ],
            ),
          ),
          centerTitle: true,
          actions: [
            PopupMenuButton<_ChatMenuAction>(
              enabled: !_busy,
              onSelected: (action) {
                switch (action) {
                  case _ChatMenuAction.unmatch:
                    _unmatch();
                  case _ChatMenuAction.report:
                    _report();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ChatMenuAction.unmatch,
                  child: Text('Deshacer match'),
                ),
                PopupMenuItem(
                  value: _ChatMenuAction.report,
                  child: Text('Reportar'),
                ),
              ],
            ),
          ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessages(context)),
              ChatInputBar(
                controller: input,
                sending: controller.sending,
                onSend: () async {
                  final text = input.text;
                  if (text.trim().isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);

                  input.clear();
                  try {
                    await controller.send(text);

                    if (!mounted) return;
                    _scrollToBottom();
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error enviando: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(
                'Error cargando mensajes',
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

    final msgs = controller.messages;
    if (msgs.isEmpty) {
      return Center(
        child: Text(
          'No hay mensajes todavia',
          style: context.textStyles.titleMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(16),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final m = msgs[i];

        return ChatMessageBubble(
          text: m.text,
          time: _formatTime(m.createdAt),
          isMe: m.senderId == widget.myUserId,
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}
