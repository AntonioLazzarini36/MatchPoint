class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        matchId: json['matchId'] as String,
        senderId: json['senderId'] as String,
        text: (json['text'] ?? '') as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
      );
}