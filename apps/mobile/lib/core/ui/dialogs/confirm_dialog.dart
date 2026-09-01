import 'package:flutter/material.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Diálogo de confirmación genérico sí/no. Devuelve `true` solo si se
/// confirmó explícitamente (cerrar el diálogo sin elegir cuenta como no).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  /// Null = el texto por defecto del idioma activo. No pueden ser valores
  /// por defecto del parámetro porque ésos han de ser constantes, y el texto
  /// depende del idioma puesto en ese momento.
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel ?? S.current.cancel),
        ),
        destructive
            ? FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel ?? S.current.confirm),
              )
            : FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel ?? S.current.confirm),
              ),
      ],
    ),
  );

  return confirmed ?? false;
}
