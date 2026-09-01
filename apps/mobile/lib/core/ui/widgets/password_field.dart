import 'package:flutter/material.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Un campo de contraseña que se puede destapar.
///
/// Sin esto no había forma de saber qué habías escrito: en un móvil, con el
/// teclado corrigiendo y los puntitos tapándolo todo, un dedazo sólo se
/// descubre cuando la app dice "credenciales incorrectas" — y ahí ya no sabes
/// si te equivocaste al escribir o si la contraseña no era ésa. Es la
/// diferencia entre un tropiezo de dos segundos y perder la cuenta.
///
/// Está aquí y no copiado en cada pantalla porque son cuatro campos —
/// entrar, registrarse, repetir, y elegir una nueva al recuperarla— y la
/// tentación de que se comporten distinto es real.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.helperText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? helperText;
  final bool autofocus;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  /// Empieza tapada, siempre. Destaparla es una decisión de quien escribe,
  /// no algo que la app haga por su cuenta — a veces hay alguien mirando.
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: _hidden,
      // Sin autocorrección ni sugerencias: el teclado no debe "arreglar" una
      // contraseña, y menos aún guardarla en su diccionario.
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        suffixIcon: IconButton(
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          tooltip: _hidden ? S.current.showPassword : S.current.hidePassword,
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}
