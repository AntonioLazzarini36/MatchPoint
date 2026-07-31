import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:match_point/core/network/api.dart';
import '../auth_controller.dart';
import '../models/register_request.dart';
import '../services/auth_service.dart';
import '../../onboarding/services/profile_service.dart';

class OnboardingAuthScreen extends StatefulWidget {
  const OnboardingAuthScreen({super.key});

  @override
  State<OnboardingAuthScreen> createState() => _OnboardingAuthScreenState();
}

class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {
  // El único punto de entrada a esta pantalla es el botón "Get Started" de
  // WelcomeScreen, pensado para gente nueva — por eso arranca en modo
  // registro. Quien ya tenga cuenta usa el enlace de abajo para cambiar.
  bool isLogin = false;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  late final AuthController controller;
  late final AuthService authService;

  // Solo para el check de email del registro — controller.isLoading es de
  // AuthController y ahí ya no se usa para registrar (eso pasa al final
  // del wizard, ver OnboardingProfileScreen).
  bool _checkingEmail = false;

  @override
  void initState() {
    super.initState();

    // ⚠️ Pon aqui tu baseUrl real (ej: http://10.0.2.2:3000 para Android emulator)
    authService = AuthService(Api.client);
    controller = AuthController(authService);
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin(String email, String pass) async {
    final ok = await controller.login(email, pass);
    if (!mounted || !ok) return;

    try {
      final profileService = ProfileService(Api.client);
      final me = await profileService.getMe();
      if (!mounted) return;

      final profile = me.profile;
      final complete = profile != null && profile.photos.isNotEmpty;

      if (complete) {
        context.go(AppRoutes.shell);
      } else {
        // Cuenta existente pero a medias (de un intento de onboarding
        // interrumpido antes de este arreglo) — sin `extra`: ya hay
        // token, solo falta completar el perfil, no registrar de nuevo.
        context.go(AppRoutes.onboarding);
      }
    } catch (e) {
      controller.setError('Could not load profile. Please try again.');
    }
  }

  Future<void> _submitRegister(String email, String pass) async {
    setState(() {
      _checkingEmail = true;
      controller.setError(null);
    });

    try {
      final available = await authService.isEmailAvailable(email);
      if (!mounted) return;

      if (!available) {
        controller.setError('Ese email ya está en uso');
        return;
      }

      // Nada se crea todavía: el registro se completa entero (usuario +
      // perfil + foto) al terminar el wizard de onboarding.
      context.go(
        AppRoutes.onboarding,
        extra: RegisterRequest(email: email, password: pass),
      );
    } catch (e) {
      controller.setError('No se pudo comprobar el email: $e');
    } finally {
      if (mounted) setState(() => _checkingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = controller.isLoading || _checkingEmail;

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
                  onPressed: busy
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

                          if (isLogin) {
                            await _submitLogin(email, pass);
                            return;
                          }

                          final confirm = confirmPassCtrl.text;
                          if (pass != confirm) {
                            controller.setError('Passwords do not match');
                            return;
                          }

                          await _submitRegister(email, pass);
                        },
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLogin ? 'Login' : 'Register'),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? 'No tienes cuenta? Registrate'
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
