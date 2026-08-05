import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../services/auth_service.dart';

/// Pantalla para confirmar que el email de la cuenta es tuyo, metiendo el
/// código de 6 dígitos que llega por correo.
///
/// Código y no enlace a propósito: en el móvil, abrir un enlace del correo
/// te saca de la app y hace falta montar deep links para volver; seis
/// números se copian y ya está. Además es la misma pieza que hará falta
/// el día que se añada 2FA.
///
/// Devuelve `true` si el email quedó verificado.
class EmailVerificationScreen extends StatefulWidget {
  /// Sólo para enseñarlo en pantalla ("te hemos escrito a ...") — quién
  /// recibe el código lo decide el backend a partir del token, no esto.
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _service = AuthService(Api.client);
  final _controller = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  String? _error;
  String? _info;

  /// Segundos que faltan para poder reenviar. El backend impone 60s y
  /// responde 429; la cuenta atrás está aquí para no dejar al usuario
  /// pulsar un botón que ya sabemos que va a fallar.
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // El código se pide solo al entrar: si has llegado a esta pantalla es
    // justo porque quieres verificar, así que un botón extra de "enviar"
    // sería un paso de más.
    _send(initial: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _send({bool initial = false}) async {
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      await _service.sendVerificationCode();
      if (!mounted) return;
      setState(() => _info = initial
          ? 'Te hemos enviado un código'
          : 'Código reenviado');
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'El código tiene 6 dígitos');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      await _service.verifyEmail(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _controller.clear();
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = _sending || _verifying;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu email')),
      // Scroll porque el teclado numérico se come media pantalla.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: colors.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Escribe el código',
              style: context.textStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Te hemos escrito a ${widget.email}. El código caduca en 15 '
              'minutos.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              // Sólo dígitos: el campo no debería aceptar nada que el
              // backend vaya a rechazar seguro.
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: context.textStyles.headlineMedium?.copyWith(
                letterSpacing: 12,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '------',
                counterText: '',
              ),
              onChanged: (value) {
                // Con los 6 dígitos puestos, verificar solo: pedir además
                // un toque en el botón es un paso que no aporta nada.
                if (value.length == 6 && !busy) _verify();
              },
              onSubmitted: (_) => _verify(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: colors.error,
                ),
              ),
            ] else if (_info != null) ...[
              const SizedBox(height: 8),
              Text(
                _info!,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _verify,
              child: _verifying
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verificar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: (busy || _cooldown > 0) ? null : _send,
              child: Text(
                _cooldown > 0
                    ? 'Reenviar código ($_cooldown s)'
                    : 'Reenviar código',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
