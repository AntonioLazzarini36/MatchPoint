import 'dart:convert';
import '../../../core/network/api_error.dart';
import 'package:match_point/core/network/api_client.dart';
import '../models/chat_message.dart';

class ChatService {
  final ApiClient api;
  ChatService(this.api);

  Future<List<ChatMessage>> fetchMessages({
    required String matchId,
    int limit = 50,
    String? cursor, // ISO string (createdAt) para paginar en el futuro
  }) async {
    var path = '/chats/$matchId/messages?limit=$limit';
    if (cursor != null && cursor.isNotEmpty) {
      path += '&cursor=${Uri.encodeQueryComponent(cursor)}';
    }

    final res = await api.get(path, auth: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se han podido cargar los mensajes');
    }

    final decoded = jsonDecode(res.body);
    final List<dynamic> list = decoded is List ? decoded : const <dynamic>[];

    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String matchId,
    required String text,
  }) async {
    final res = await api.post(
      '/chats/$matchId/messages',
      auth: true,
      body: {'text': text},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido enviar el mensaje');
    }

    return ChatMessage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> markRead({required String matchId}) async {
    final res = await api.patch('/chats/$matchId/read', auth: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se han podido marcar como leídos');
    }
  }
}
