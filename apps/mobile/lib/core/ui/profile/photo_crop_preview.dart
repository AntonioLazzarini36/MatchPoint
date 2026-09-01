import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/landscape_crop.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Enseña cómo van a quedar las fotos ya recortadas a 16:9 antes de
/// aceptarlas.
///
/// Sin esto el recorte al centro es una sorpresa: subes una foto vertical
/// y la app se queda con una franja del medio sin avisar. Aquí se ve el
/// resultado exacto y se puede descartar.
///
/// Acepta **varias a la vez** a propósito: ir de una en una (elegir,
/// recortar, confirmar, subir, repetir) hace eterno rellenar un perfil de
/// 5 fotos, que es justo lo primero que hace alguien nuevo.
///
/// Devuelve la lista de fotos ya recortadas que el usuario ha aceptado, o
/// null si descarta todo.
Future<List<Uint8List>?> showPhotoCropPreview(
  BuildContext context, {
  required List<Uint8List> originals,
}) async {
  if (originals.isEmpty) return null;

  final cropped = <Uint8List>[];
  for (final bytes in originals) {
    cropped.add(await cropToLandscape(bytes));
  }
  if (!context.mounted) return null;

  return showDialog<List<Uint8List>>(
    context: context,
    builder: (_) => _CropPreviewDialog(cropped: cropped),
  );
}

class _CropPreviewDialog extends StatefulWidget {
  final List<Uint8List> cropped;

  const _CropPreviewDialog({required this.cropped});

  @override
  State<_CropPreviewDialog> createState() => _CropPreviewDialogState();
}

class _CropPreviewDialogState extends State<_CropPreviewDialog> {
  late final List<Uint8List> _kept = List.of(widget.cropped);

  @override
  Widget build(BuildContext context) {
    final several = widget.cropped.length > 1;

    return AlertDialog(
      title: Text(several ? S.current.thisIsHowTheyLook : S.current.thisIsHowItLooks),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _kept.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _preview(context, i),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              several
                  ? S.current.landscapeCropExplainerMany
                  : S.current.landscapeCropExplainerOne,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(several ? S.current.discardAll : S.current.chooseAnother),
        ),
        FilledButton(
          onPressed: _kept.isEmpty
              ? null
              : () => Navigator.of(context).pop(List.of(_kept)),
          child: Text(
            _kept.length > 1 ? S.current.useTheseCount(_kept.length) : S.current.useThisOne,
          ),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            aspectRatio: kPhotoAspectRatio,
            child: Image.memory(_kept[index], fit: BoxFit.cover),
          ),
        ),
        // Sólo tiene sentido quitar una cuando hay varias: con una sola,
        // "quitar" y "elegir otra" serían el mismo botón dos veces.
        if (_kept.length > 1)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _kept.removeAt(index)),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
