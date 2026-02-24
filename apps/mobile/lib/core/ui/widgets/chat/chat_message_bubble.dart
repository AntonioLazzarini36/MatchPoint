import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

class ChatMessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? context.colors.primary : context.colors.surfaceContainerHighest;
    final fg = isMe ? context.colors.onPrimary : context.colors.onSurface;
    final timeColor = isMe
        ? context.colors.onPrimary.withValues(alpha: 0.75)
        : context.colors.onSurfaceVariant;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: context.textStyles.bodyMedium?.copyWith(color: fg)),
            const SizedBox(height: 2),
            Text(
              time,
              style: context.textStyles.labelSmall?.copyWith(
                color: timeColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}