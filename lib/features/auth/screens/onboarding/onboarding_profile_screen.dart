import 'package:flutter/material.dart';

class OnboardingProfileScreen extends StatelessWidget {
  const OnboardingProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'Onboarding Profile (próximamente)\n- deportes principales\n- nivel\n- preferencias',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}