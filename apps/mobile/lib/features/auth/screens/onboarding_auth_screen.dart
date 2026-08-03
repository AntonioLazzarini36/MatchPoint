import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/ui/widgets/app_logo_placeholder.dart';
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

  final passFocus = FocusNode();
  // Enter avanza de campo en campo y al final envía el formulario, igual
  // que tocar el botón — nunca inserta un salto de línea.
  final confirmPassFocus = FocusNode();

  late final AuthController controller;
  late final AuthService authService;

  bool _checkingEmail = false;

  @override
  void initState() {
    super.initState();
    authService = AuthService(Api.client);
    controller = AuthController(authService);
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    passFocus.dispose();
    confirmPassFocus.dispose();
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

  bool get _busy => controller.isLoading || _checkingEmail;

  Future<void> _submit() async {
    if (_busy) return;

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

    if (pass.length < 8) {
      controller.setError('La contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (pass.length > 72) {
      controller.setError('La contraseña no puede superar los 72 caracteres');
      return;
    }

    final confirm = confirmPassCtrl.text;
    if (pass != confirm) {
      controller.setError('Passwords do not match');
      return;
    }

    await _submitRegister(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = _busy;

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
                const Center(child: AppLogoPlaceholder(size: 64)),
                const SizedBox(height: 20),
                Text(
                  isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                  style: t.headlineSmall,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => passFocus.requestFocus(),
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  focusNode: passFocus,
                  obscureText: true,
                  textInputAction:
                      isLogin ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: (_) {
                    if (isLogin) {
                      _submit();
                    } else {
                      confirmPassFocus.requestFocus();
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    focusNode: confirmPassFocus,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
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
                  onPressed: busy ? null : _submit,
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
