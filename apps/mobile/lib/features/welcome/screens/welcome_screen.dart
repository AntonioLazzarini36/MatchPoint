import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/ui/widgets/background_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return BackgroundScaffold(
      assetPath: 'assets/images/welcome.jpg',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            'MatchPoint',
            textAlign: TextAlign.center,
            style: t.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Encuentra partners deportivos\nque encajen contigo.',
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const Spacer(),

          FilledButton(
            onPressed: () => context.go(AppRoutes.onboardingAuth),
            child: const Text('Get Started'),
          ),
          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: null,
            child: const Text('Google (proximamente)'),
          ),
          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: null,
            child: const Text('Apple (proximamente)'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
