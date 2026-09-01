import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/i18n/app_locale.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/ui/widgets/password_field.dart';

import '../services/auth_service.dart';

/// Recuperar la contraseña olvidada.
///
/// El agujero que tapa: la única forma de entrar era acordarse. Quien no se
/// acordaba perdía la cuenta y con ella sus matches y sus conversaciones — y
/// como no hay login con Google, no había ninguna otra puerta. Es el fallo que
/// se lleva por delante a gente que sí quería usar la app.
///
/// Los dos pasos van en **una sola pantalla** y no en dos: el código llega al
/// correo, así que hay que salir de la app a buscarlo, y volver a un sitio
/// distinto del que dejaste es donde se pierde la gente. Aquí vuelves y el
/// campo del código está justo debajo del correo que ya escribiste.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail});

  /// Lo que hubiera escrito en el login, para no pedirlo dos veces.
  final String? initialEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _service = AuthService(Api.client);

  late final _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  /// Se pasa al segundo paso en cuanto el código sale — no cuando llega,
  /// porque eso no se puede saber desde aquí.
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = S.current.writeYourEmail);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _service.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        // "Si esa cuenta existe" no es un adorno legal: el backend contesta
        // lo mismo exista o no, para que esta pantalla no sirva para
        // averiguar quién está registrado. El texto tiene que ser honesto
        // con lo que la app de verdad sabe.
        _info = S.current.ifAccountExistsCodeSent;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;

    if (code.length != 6) {
      setState(() => _error = S.current.codeIsSixDigits);
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = S.current.passwordNeedsEightChars);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _service.confirmPasswordReset(
        email: _emailCtrl.text.trim(),
        code: code,
        newPassword: pass,
      );
      if (!mounted) return;
      Navigator.of(context).pop(_emailCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _codeCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = context.textStyles;

    return Scaffold(
      appBar: AppBar(title: Text(S.current.recoverPassword)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_reset, size: 56, color: colors.primary),
            const SizedBox(height: 20),
            Text(
              _codeSent ? S.current.writeTheCode : S.current.whatIsYourEmail,
              style: t.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? S.current.codeSixDigitsFifteenMin
                  : S.current.weSendYouACode,
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            TextField(
              controller: _emailCtrl,
              enabled: !_codeSent && !_busy,
              autofocus: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _requestCode(),
              decoration: InputDecoration(labelText: S.current.email),
            ),

            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: t.headlineSmall?.copyWith(
                  letterSpacing: 10,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '------',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              PasswordField(
                controller: _passCtrl,
                labelText: S.current.newPassword,
                helperText: S.current.minEightChars,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirm(),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: colors.error),
              ),
            ] else if (_info != null) ...[
              const SizedBox(height: 12),
              Text(
                _info!,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: colors.primary),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _confirm : _requestCode),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? S.current.changePassword : S.current.sendCode),
            ),

            if (_codeSent) ...[
              const SizedBox(height: 4),
              TextButton(
                // Volver al primer paso, por si el correo estaba mal escrito
                // — que es la mitad de las veces que esto no funciona.
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _error = null;
                        _info = null;
                      }),
                child: Text(S.current.useAnotherEmail),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              S.current.changingClosesSessions,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
