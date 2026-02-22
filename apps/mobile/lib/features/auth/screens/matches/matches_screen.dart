import 'package:flutter/material.dart';
import '../../../../app/routes.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
          child: const Text('Abrir Chat (placeholder)'),
        ),
      ),
    );
  }
}
