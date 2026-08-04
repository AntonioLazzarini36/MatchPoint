import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/landscape_crop.dart';

/// Enseña como va a quedar la foto ya recortada a 16:9 antes de aceptarla.
///
/// Sin esto el recorte al centro es una sorpresa: subes una foto vertical
/// y la app se queda con una franja del medio sin avisar. Aqui se ve el
/// resultado exacto y se puede descartar y elegir otra.
///
/// Devuelve los bytes ya recortados si se acepta, o null si se descarta.
Future<Uint8List?> showPhotoCropPreview(
  BuildContext context, {
  required Uint8List original,
}) async {
  final cropped = await cropToLandscape(original);
  if (!context.mounted) return null;

  return showDialog<Uint8List>(
    context: context,
    builder: (dialogContext) => _CropPreviewDialog(cropped: cropped),
  );
}

class _CropPreviewDialog extends StatelessWidget {
  final Uint8List cropped;

  const _CropPreviewDialog({required this.cropped});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Así se verá'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AspectRatio(
              aspectRatio: kPhotoAspectRatio,
              child: Image.memory(cropped, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'MatchPoint usa fotos horizontales, así que la recortamos por '
            'el centro. Si te corta algo importante, elige otra.',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Elegir otra'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(cropped),
          child: const Text('Usar esta'),
        ),
      ],
    );
  }
}
