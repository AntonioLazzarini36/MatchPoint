import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String matchId;

  const ChatScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(
        child: Text(
          'Chat del match:\n$matchId',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}