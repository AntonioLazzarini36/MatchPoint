import 'package:flutter/foundation.dart';
import 'models/chat_message.dart';
import 'services/chat_service.dart';

class ChatController extends ChangeNotifier {
  final ChatService service;
  final String matchId;

  ChatController({required this.service, required this.matchId});

  bool loading = false;
  bool sending = false;
  String? error;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> init() async {
    await reload();
    // marcar leido al entrar (best effort)
    try {
      await service.markRead(matchId: matchId);
    } catch (_) {}
  }

  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final msgs = await service.fetchMessages(matchId: matchId);
      _messages
        ..clear()
        ..addAll(msgs);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    sending = true;
    notifyListeners();

    try {
      final created = await service.sendMessage(matchId: matchId, text: t);
      _messages.add(created);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }
}
