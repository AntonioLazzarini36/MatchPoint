import 'package:flutter/material.dart';

class PartnerDetailScreen extends StatelessWidget {
  const PartnerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partner Detail')),
      body: const Center(
        child: Text(
          'Partner Detail (próximamente)',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
