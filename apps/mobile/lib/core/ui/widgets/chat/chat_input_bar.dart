import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:match_point/core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  // Enter envia (como "he terminado de escribir"), Shift+Enter sigue
  // permitiendo un salto de linea real para mensajes largos.
  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: (node, event) {
      final isEnter =
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter;
      if (event is KeyDownEvent &&
          isEnter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (!widget.sending) widget.onSend();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!widget.sending) widget.onSend();
                },
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.colors.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send, color: context.colors.primary),
              onPressed: widget.sending ? null : widget.onSend,
            ),
          ],
        ),
      ),
    );
  }
}
