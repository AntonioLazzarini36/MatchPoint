import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:match_point/app/routes.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../chat_controller.dart';
import '../services/chat_service.dart';

import '../../../core/ui/widgets/chat/chat_message_bubble.dart';
import '../../../core/ui/widgets/chat/chat_input_bar.dart';

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
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = ChatController(
      service: ChatService(Api.client),
      matchId: widget.matchId,
    );
    controller.init().then((_) => _scrollToBottom());
  }

  @override
  void dispose() {
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
