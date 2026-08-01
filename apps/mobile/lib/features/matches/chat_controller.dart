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

  /// Polled periodically by ChatScreen while it's open. Fetches the most
  /// recent messages and appends any not already in `_messages` — no
  /// websocket/push, just short-interval polling. Silent on failure
  /// (transient network hiccups shouldn't interrupt an open chat), and
  /// marks the match read again if new messages came in, so unread state
  /// in the matches list stays accurate for messages that arrive while
  /// the chat is already open.
  Future<void> pollNewMessages() async {
    try {
      final latest = await service.fetchMessages(matchId: matchId);
      final existingIds = _messages.map((m) => m.id).toSet();
      final newOnes = latest.where((m) => !existingIds.contains(m.id));
      if (newOnes.isEmpty) return;

      _messages
        ..addAll(newOnes)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();

      try {
        await service.markRead(matchId: matchId);
      } catch (_) {}
    } catch (_) {}
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
