import 'package:flutter/material.dart';

const _reportReasons = [
  'Comportamiento inapropiado',
  'Perfil falso',
  'Spam o publicidad',
  'Contenido ofensivo',
  'Otro',
];

/// Diálogo para elegir un motivo de reporte. Devuelve el motivo elegido,
/// o `null` si se canceló. Reportar no borra el match — si además quieres
/// cortar todo contacto, eso es un unmatch aparte.
Future<String?> showReportReasonDialog(BuildContext context) {
  String selected = _reportReasons.first;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Reportar usuario'),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => setState(() => selected = value!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in _reportReasons)
                RadioListTile<String>(
                  value: reason,
                  title: Text(reason),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: const Text('Reportar'),
          ),
        ],
      ),
    ),
  );
}
