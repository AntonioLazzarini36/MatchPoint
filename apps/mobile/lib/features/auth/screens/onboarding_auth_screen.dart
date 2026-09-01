import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/i18n/app_locale.dart';
import 'package:match_point/core/i18n/language_selector.dart';
import 'package:match_point/core/network/public_config.dart';
import 'package:match_point/core/ui/widgets/app_logo.dart';
import 'package:match_point/core/ui/widgets/password_field.dart';
import 'password_reset_screen.dart';
import '../auth_controller.dart';
import '../models/register_request.dart';
import '../services/auth_service.dart';
import '../../onboarding/services/profile_service.dart';
import '../../../core/network/connection_error.dart';

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

  /// Empieza en false y se enciende con la respuesta del servidor: mejor que
  /// el enlace aparezca un instante tarde a que parpadee y desaparezca.
  bool _canResetPassword = false;

  @override
  void initState() {
    super.initState();
    authService = AuthService(Api.client);
    controller = AuthController(authService);
    PublicConfig.emailEnabled().then((value) {
      if (mounted) setState(() => _canResetPassword = value);
    });
  }

  Future<void> _openPasswordReset() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            PasswordResetScreen(initialEmail: emailCtrl.text.trim()),
      ),
    );
    if (!mounted || email == null) return;
    // Vuelve con el correo ya puesto y el foco en la contraseña: acaba de
    // elegir una nueva, lo siguiente es escribirla aquí.
    emailCtrl.text = email;
    passCtrl.clear();
    passFocus.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.current.passwordChangedSignIn)),
    );
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
      controller.setError(S.current.couldNotLoadYourProfile);
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
        controller.setError(S.current.emailAlreadyInUse);
        return;
      }

      context.go(
        AppRoutes.onboarding,
        extra: RegisterRequest(email: email, password: pass),
      );
    } catch (e) {
      controller.setError(
        friendlyError(e, fallback: S.current.couldNotCheckEmail),
      );
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
      controller.setError(S.current.writeYourEmail);
      return;
    }

    if (!email.contains('@')) {
      controller.setError(S.current.emailLooksInvalid);
      return;
    }

    if (isLogin) {
      await _submitLogin(email, pass);
      return;
    }

    if (pass.length < 8) {
      controller.setError(S.current.passwordAtLeastEight);
      return;
    }
    if (pass.length > 72) {
      controller.setError(S.current.passwordAtMost72);
      return;
    }

    final confirm = confirmPassCtrl.text;
    if (pass != confirm) {
      controller.setError(S.current.passwordsDoNotMatch);
      return;
    }

    await _submitRegister(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = _busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isLogin ? S.current.signIn : S.current.createAccount,
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          // Scroll obligatorio, no decorativo: al abrir el teclado el
          // alto disponible se queda en la mitad y un `Column` pelado
          // desbordaba ("BOTTOM OVERFLOWED BY 54 PIXELS"). Con el scroll,
          // el propio `Scaffold` reduce el viewport y el formulario se
          // desplaza en vez de romperse.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 64)),
                const SizedBox(height: 20),
                Text(
                  isLogin ? S.current.welcomeBack : S.current.createYourAccount,
                  style: t.headlineSmall,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => passFocus.requestFocus(),
                  decoration: InputDecoration(labelText: S.current.email),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: passCtrl,
                  focusNode: passFocus,
                  labelText: S.current.password,
                  textInputAction: isLogin
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onSubmitted: (_) {
                    if (isLogin) {
                      _submit();
                    } else {
                      confirmPassFocus.requestFocus();
                    }
                  },
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: confirmPassCtrl,
                    focusNode: confirmPassFocus,
                    labelText: S.current.repeatPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 24),

                if (controller.error != null) ...[
                  Text(
                    controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                      : Text(isLogin ? S.current.signIn : S.current.createAccount),
                ),

                // Sólo al entrar: en el registro no hay contraseña que
                // recuperar todavía. Y sólo si esta instalación puede mandar
                // correos — si no, el enlace acaba siempre en un 503.
                if (isLogin && _canResetPassword) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: busy ? null : _openPasswordReset,
                    child: Text(S.current.forgotPassword),
                  ),
                ] else
                  const SizedBox(height: 12),

                // El selector de idioma, a la vista y no escondido en Ajustes:
                // quien abre la app por primera vez y la ve en un idioma que no
                // habla no puede llegar a Ajustes — no sabe leer el camino.
                const SizedBox(height: 8),
                const Center(child: LanguageToggle()),
                const SizedBox(height: 4),

                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? S.current.noAccountRegister
                        : S.current.haveAccountSignIn,
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
