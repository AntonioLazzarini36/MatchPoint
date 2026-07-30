import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Fallback para cuando `XFile.mimeType` viene vacío (pasa en algunas
/// plataformas nativas; en web `image_picker` sí lo rellena). Debe cubrir
/// exactamente los tipos que acepta `me::photos::extension_for` en el backend.
String guessPhotoContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Grid de fotos + tile de "añadir" + borrar por foto. Presentacional puro
/// — quien lo usa (`PhotoManagerSheet`, `OnboardingPhotoStep`) es quien
/// gestiona subir/borrar de verdad; este widget solo pinta el estado que
/// le pasan y avisa mediante `onAdd`/`onDelete`.
class PhotoGridEditor extends StatelessWidget {
  static const maxPhotos = 6;

  final List<String> photos;
  final bool busy;
  final VoidCallback? onAdd;
  final ValueChanged<String>? onDelete;

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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length + (photos.length < maxPhotos ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == photos.length) {
          return _AddTile(busy: busy, onTap: busy ? null : onAdd);
        }
        final url = photos[index];
        final canDelete = !busy && photos.length > 1 && onDelete != null;
        return _PhotoTile(
          url: url,
          onDelete: canDelete ? () => onDelete!(url) : null,
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
  final String url;
  final VoidCallback? onDelete;

  const _PhotoTile({required this.url, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(url, fit: BoxFit.cover),
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
