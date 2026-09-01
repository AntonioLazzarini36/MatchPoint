import 'package:flutter/material.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Los motivos de un reporte.
///
/// Cada uno tiene **dos** textos y no es por gusto:
///
/// - `value` es lo que se manda al servidor. Va siempre en castellano y no
///   cambia con el idioma de quien reporta: la cola de moderación
///   (`/admin/reports`) la lee una persona, y si el motivo llegara en el
///   idioma de cada usuario, filtrar o contar "cuántos reportes por perfil
///   falso" dejaría de funcionar en cuanto reporte alguien con la app en
///   inglés.
/// - `label` es lo que se ve, traducido.
///
/// Es la distinción de siempre entre el dato y su presentación, y aquí se nota
/// porque el que lee el dato no es el que lo escribe.
class _Reason {
  const _Reason(this.value, this.label);
  final String value;
  final String label;
}

List<_Reason> get _reportReasons => [
  _Reason('Comportamiento inapropiado', S.current.reasonInappropriate),
  _Reason('Perfil falso', S.current.reasonFakeProfile),
  _Reason('Spam o publicidad', S.current.reasonSpam),
  _Reason('Contenido ofensivo', S.current.reasonOffensive),
  _Reason('Otro', S.current.reasonOther),
];

/// Diálogo para elegir un motivo de reporte. Devuelve el motivo elegido,
/// o `null` si se canceló. Reportar no borra el match — si además quieres
/// cortar todo contacto, eso es un unmatch aparte.
Future<String?> showReportReasonDialog(BuildContext context) {
  final reasons = _reportReasons;
  String selected = reasons.first.value;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(S.current.reportUser),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => setState(() => selected = value!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in reasons)
                RadioListTile<String>(
                  value: reason.value,
                  title: Text(reason.label),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(S.current.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text(S.current.report),
          ),
        ],
      ),
    ),
  );
}
