import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Un campo que va a cambiar, con su valor antes y después.
class FieldChange {
  final String label;
  final String before;
  final String after;

  const FieldChange({
    required this.label,
    required this.before,
    required this.after,
  });

  bool get isReal => before.trim() != after.trim();
}

/// Confirmación antes de guardar cambios del perfil, enseñando **qué**
/// cambia y **de qué a qué**.
///
/// Antes cada hoja de Ajustes guardaba en cuanto se cerraba: tocabas algo
/// sin querer, se cerraba la hoja, y tu perfil ya era otro sin que
/// mediara ni un aviso. Y peor, sin forma de saber qué habías tocado.
///
/// Sólo se listan los campos que de verdad cambian: repetir los que se
/// quedan igual convierte el diálogo en ruido que nadie lee.
///
/// Devuelve true si se confirma. Si no hay ningún cambio real devuelve
/// false sin preguntar nada — no hay nada que guardar ni que confirmar.
Future<bool> confirmChanges(
  BuildContext context, {
  required String title,
  required List<FieldChange> changes,
}) async {
  final real = changes.where((c) => c.isReal).toList();
  if (real.isEmpty) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              real.length == 1
                  ? 'Se va a cambiar esto:'
                  : 'Se van a cambiar ${real.length} cosas:',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: real.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ChangeRow(change: real[i]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Guardar cambios'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

class _ChangeRow extends StatelessWidget {
  final FieldChange change;

  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(change.label, style: context.textStyles.titleSmall),
        const SizedBox(height: 4),
        Text(
          change.before.trim().isEmpty ? 'Sin poner' : change.before,
          style: context.textStyles.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            // Tachado: se ve de un vistazo cuál es el valor que se va.
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.subdirectory_arrow_right, size: 16, color: colors.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                change.after.trim().isEmpty ? 'Sin poner' : change.after,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
