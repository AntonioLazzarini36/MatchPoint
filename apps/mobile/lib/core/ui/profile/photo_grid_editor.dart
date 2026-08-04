import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/landscape_crop.dart';

/// Fallback para cuando `XFile.mimeType` viene vacío (pasa en algunas
/// plataformas nativas; en web `image_picker` sí lo rellena). Debe cubrir
/// exactamente los tipos que acepta `me::photos::extension_for` en el backend.
String guessPhotoContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Una foto ya subida (tiene URL) o todavía solo elegida en el dispositivo
/// (bytes en memoria, sin subir — caso del onboarding, que no toca el
/// backend hasta completar el registro entero al final).
sealed class PhotoTileData {
  const PhotoTileData();
}

class RemotePhoto extends PhotoTileData {
  final String url;
  const RemotePhoto(this.url);
}

class LocalPhoto extends PhotoTileData {
  final Uint8List bytes;
  const LocalPhoto(this.bytes);
}

/// Grid de fotos + tile de "añadir" + borrar por foto. Presentacional puro
/// — quien lo usa (`PhotoManagerSheet`, `OnboardingPhotoStep`) es quien
/// gestiona subir/borrar de verdad; este widget solo pinta el estado que
/// le pasan y avisa mediante `onAdd`/`onDelete` (por índice, válido tanto
/// para fotos remotas como locales).
class PhotoGridEditor extends StatelessWidget {
  static const maxPhotos = 6;

  final List<PhotoTileData> photos;
  final bool busy;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onDelete;

  const PhotoGridEditor({
    super.key,
    required this.photos,
    required this.busy,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Dos columnas en 16:9 en vez de tres cuadradas: las fotos se
      // guardan ya recortadas a horizontal (ver landscape_crop.dart), asi
      // que una rejilla cuadrada las volvia a recortar en pantalla y no se
      // parecia a lo que el usuario habia aceptado al subirlas.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: kPhotoAspectRatio,
      ),
      itemCount: photos.length + (photos.length < maxPhotos ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == photos.length) {
          return _AddTile(busy: busy, onTap: busy ? null : onAdd);
        }
        final canDelete = !busy && photos.length > 1 && onDelete != null;
        return _PhotoTile(
          data: photos[index],
          onDelete: canDelete ? () => onDelete!(index) : null,
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;

  const _AddTile({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: busy
              ? const CircularProgressIndicator()
              : Icon(Icons.add_a_photo, color: context.colors.outline),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoTileData data;
  final VoidCallback? onDelete;

  const _PhotoTile({required this.data, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final image = switch (data) {
      RemotePhoto(:final url) => Image.network(url, fit: BoxFit.cover),
      LocalPhoto(:final bytes) => Image.memory(bytes, fit: BoxFit.cover),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
