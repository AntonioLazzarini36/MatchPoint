import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';

/// De dónde sale la foto: cámara o galería.
///
/// Hasta ahora sólo se podía elegir de la galería, lo que obliga a salir de
/// la app, hacerse la foto y volver — justo en el momento en que alguien
/// está creando su perfil y tiene menos paciencia. La cámara devuelve una
/// sola foto (es lo que hace una cámara); la galería, varias de una vez.
///
/// Devuelve las fotos elegidas, o lista vacía si se cancela.
Future<List<XFile>> pickPhotos(
  BuildContext context, {
  required int limit,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('Añadir foto', style: context.textStyles.titleMedium),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_camera_outlined,
              color: context.colors.primary,
            ),
            title: const Text('Hacer una foto'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_library_outlined,
              color: context.colors.primary,
            ),
            title: const Text('Elegir de la galería'),
            subtitle: Text(
              limit == 1 ? 'Una foto' : 'Puedes elegir hasta $limit',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return const [];

  final picker = ImagePicker();
  if (source == ImageSource.camera) {
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      // La trasera: una foto de perfil de alguien jugando la hace otra
      // persona, no es un selfie.
      preferredCameraDevice: CameraDevice.rear,
    );
    return photo == null ? const [] : [photo];
  }

  return picker.pickMultiImage(imageQuality: 85, limit: limit);
}
