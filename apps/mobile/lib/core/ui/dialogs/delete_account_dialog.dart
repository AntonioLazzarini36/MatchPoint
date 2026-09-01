import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Palabra que hay que escribir para confirmar. En mayúsculas y en
/// castellano, igual que el botón.
const _confirmWord = 'BORRAR';

/// Confirmación para borrar la cuenta.
///
/// Pide **escribir la palabra**, no sólo pulsar "sí". Un diálogo de dos
/// botones se despacha con un toque reflejo, y esto no tiene deshacer: no
/// hay papelera, ni copia, ni forma de recuperarlo. Escribir seis letras
/// obliga a leer lo que hay encima.
///
/// Y encima lista **qué se pierde**, en concreto y no en abstracto: la
/// diferencia entre "se borrarán tus datos" y "tus conversaciones y tus
/// partidos acordados" es que la segunda se entiende.
///
/// Devuelve true si se confirma.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return confirmed ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  bool get _canDelete => _controller.text.trim().toUpperCase() == _confirmWord;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: Text(S.current.deleteYourAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.current.deleteCannotBeUndone,
              style: context.textStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final item in [
              S.current.yourProfileAndPhotos,
              S.current.partnersAndConversations,
              S.current.agreedSessions,
              S.current.yourLevelExperiencePreferences,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.close, size: 16, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item, style: context.textStyles.bodySmall),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              S.current.peopleWillStopSeeingYou,
              style: context.textStyles.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.current.typeToConfirm(_confirmWord),
              style: context.textStyles.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canDelete) Navigator.of(context).pop(true);
              },
              decoration: const InputDecoration(hintText: _confirmWord),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(S.current.cancel),
        ),
        FilledButton(
          // Deshabilitado hasta escribir la palabra: el botón no puede
          // pulsarse por inercia.
          onPressed: _canDelete ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          child: Text(S.current.deleteAccount),
        ),
      ],
    );
  }
}
