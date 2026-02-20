import 'package:flutter/material.dart';
import '../../app/routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'MatchPoint',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Encuentra partners deportivos\nque encajen contigo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const Spacer(),

              // Placeholder: en el futuro Google / Apple / Login
              FilledButton(
                onPressed: null,
                child: const Text('Continuar con Google (próximamente)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: null,
                child: const Text('Continuar con Apple (próximamente)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: null,
                child: const Text('Login (próximamente)'),
              ),
              const SizedBox(height: 12),

              // Por ahora: Get started nos lleva al shell directamente
              FilledButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.shell);
                  // En el futuro: AppRoutes.onboardingProfile
                },
                child: const Text('Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}