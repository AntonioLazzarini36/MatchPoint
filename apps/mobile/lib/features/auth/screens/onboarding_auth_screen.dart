import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:match_point/core/network/api.dart';
import '../auth_controller.dart';
import '../services/auth_service.dart';
import '../../onboarding/services/profile_service.dart';

class OnboardingAuthScreen extends StatefulWidget {
  const OnboardingAuthScreen({super.key});

  @override
  State<OnboardingAuthScreen> createState() => _OnboardingAuthScreenState();
}

class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {
  bool isLogin = true;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  late final AuthController controller;

  @override
  void initState() {
    super.initState();

    // ⚠️ Pon aquí tu baseUrl real (ej: http://10.0.2.2:3000 para Android emulator)
    controller = AuthController(AuthService(Api.client));
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                  style: t.headlineSmall,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                if (controller.error != null) ...[
                  Text(
                    controller.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],

                FilledButton(
                  onPressed: controller.isLoading
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          final pass = passCtrl.text;

                          if (email.isEmpty) {
                            controller.setError('Email is required');
                            return;
                          }

                          if (!email.contains('@')) {
                            controller.setError('Email is not valid');
                            return;
                          }

                          if (!isLogin) {
                            final confirm = confirmPassCtrl.text;
                            if (pass != confirm) {
                              controller.setError('Passwords do not match');
                              return;
                            }
                          }

                          final ok = isLogin
                            ? await controller.login(email, pass)
                            : await controller.register(email, pass);

                          if (!context.mounted || !ok) return;

                          try {
                            final profileService = ProfileService(Api.client);
                            final me = await profileService.getMe();

                            if (!context.mounted) return;

                            if (me.profile != null) {
                              context.go(AppRoutes.shell);
                            } else {
                              context.go(AppRoutes.onboarding);
                            }
                          } catch (e) {
                            controller.setError(
                              'Could not load profile. Please try again.',
                            );
                          }
                        },
                  child: controller.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLogin ? 'Login' : 'Register'),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: controller.isLoading
                      ? null
                      : () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? 'No tienes cuenta? Regístrate'
                        : 'Ya tienes cuenta? Login',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
