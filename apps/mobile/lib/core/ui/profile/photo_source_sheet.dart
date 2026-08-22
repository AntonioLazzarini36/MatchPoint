import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import 'avatar_gallery.dart';

/// Lo que devuelve [pickPhotos]: o ficheros de la cámara/galería, o un
/// avatar de los que trae la app. Nunca las dos cosas.
class PhotoPick {
  final List<XFile> files;
  final String? avatarAsset;

  const PhotoPick.files(this.files) : avatarAsset = null;
  const PhotoPick.avatar(String this.avatarAsset) : files = const [];
  const PhotoPick.none() : files = const [], avatarAsset = null;

  bool get isEmpty => files.isEmpty && avatarAsset == null;
}

/// De dónde sale la foto: cámara, galería o un avatar de la app.
///
/// Hasta ahora sólo se podía elegir de la galería, lo que obliga a salir de
/// la app, hacerse la foto y volver — justo en el momento en que alguien
/// está creando su perfil y tiene menos paciencia. La cámara devuelve una
/// sola foto (es lo que hace una cámara); la galería, varias de una vez.
///
/// El avatar es la salida para quien no quiere poner su cara nada más
/// llegar: el perfil necesita una foto para aparecer en Discover, y sin esta
/// opción ese requisito se come a la gente que sólo venía a echar un
/// vistazo.
///
/// Devuelve las fotos elegidas, o vacío si se cancela.
Future<PhotoPick> pickPhotos(BuildContext context, {required int limit}) async {
  final source = await showModalBottomSheet<_Source>(
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
            onTap: () => Navigator.of(context).pop(_Source.camera),
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
            onTap: () => Navigator.of(context).pop(_Source.gallery),
          ),
          ListTile(
            leading: Icon(Icons.face_outlined, color: context.colors.primary),
            title: const Text('Usar un avatar'),
            subtitle: Text(
              'Ilustraciones de la app, si prefieres no poner tu cara',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            onTap: () => Navigator.of(context).pop(_Source.avatar),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null || !context.mounted) return const PhotoPick.none();

  if (source == _Source.avatar) {
    final asset = await pickAvatar(context);
    return asset == null ? const PhotoPick.none() : PhotoPick.avatar(asset);
  }

  final picker = ImagePicker();
  if (source == _Source.camera) {
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      // La trasera: una foto de perfil de alguien jugando la hace otra
      // persona, no es un selfie.
      preferredCameraDevice: CameraDevice.rear,
    );
    return PhotoPick.files(photo == null ? const [] : [photo]);
  }

  return PhotoPick.files(
    await picker.pickMultiImage(imageQuality: 85, limit: limit),
  );
}

/// Las tres salidas de la hoja. Enum propio y no `ImageSource` porque el
/// avatar no es una fuente del `image_picker`: no abre nada del sistema.
enum _Source { camera, gallery, avatar }
