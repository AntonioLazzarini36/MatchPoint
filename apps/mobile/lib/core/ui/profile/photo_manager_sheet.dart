import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../features/onboarding/services/profile_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet para gestionar las fotos del propio perfil: grid de fotos
/// actuales + tile para añadir (abre el selector de imagen) + borrar por
/// foto. Reutilizado tanto desde `ProfileScreen` (editar) como desde el
/// onboarding (añadir la primera foto, obligatoria ahí).
class PhotoManagerSheet extends StatefulWidget {
  final ProfileService service;
  final List<String> initialPhotos;
  final ValueChanged<List<String>> onChanged;

  /// Si es `true`, no se puede cerrar el sheet hasta tener al menos 1 foto
  /// (usado en el onboarding). El backend igualmente nunca deja borrar la
  /// última foto de un perfil que ya tenía alguna, así que esto es solo la
  /// versión "obligar a añadir la primera" de esa misma regla.
  final bool requireAtLeastOne;

  const PhotoManagerSheet({
    super.key,
    required this.service,
    required this.initialPhotos,
    required this.onChanged,
    this.requireAtLeastOne = false,
  });

  static const maxPhotos = 6;

  @override
  State<PhotoManagerSheet> createState() => _PhotoManagerSheetState();
}

/// Fallback para cuando `XFile.mimeType` viene vacío (pasa en algunas
/// plataformas nativas; en web `image_picker` sí lo rellena). Debe cubrir
/// exactamente los tipos que acepta `me::photos::extension_for` en el backend.
String _guessContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class _PhotoManagerSheetState extends State<PhotoManagerSheet> {
  late List<String> _photos;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.initialPhotos);
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= PhotoManagerSheet.maxPhotos) {
      setState(() => _error = 'Máximo ${PhotoManagerSheet.maxPhotos} fotos.');
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final profile = await widget.service.uploadPhoto(
        bytes: bytes,
        filename: picked.name,
        contentType: picked.mimeType ?? _guessContentType(picked.name),
      );
      if (!mounted) return;
      setState(() => _photos = profile.photos);
      widget.onChanged(_photos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo subir la foto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    if (_photos.length <= 1) {
      setState(() => _error = 'Tu perfil necesita al menos 1 foto.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final profile = await widget.service.deletePhoto(url);
      if (!mounted) return;
      setState(() => _photos = profile.photos);
      widget.onChanged(_photos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo borrar la foto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canClose = !widget.requireAtLeastOne || _photos.isNotEmpty;

    return PopScope(
      canPop: canClose,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tus fotos', style: context.textStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: canClose
                        ? () => Navigator.of(context).pop()
                        : null,
                  ),
                ],
              ),
              if (!canClose) ...[
                const SizedBox(height: 4),
                Text(
                  'Añade al menos 1 foto para continuar.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: context.colors.error)),
              ],
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount:
                    _photos.length +
                    (_photos.length < PhotoManagerSheet.maxPhotos ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _photos.length) {
                    return _AddTile(
                      busy: _busy,
                      onTap: _busy ? null : _addPhoto,
                    );
                  }
                  final url = _photos[index];
                  final canDelete = !_busy && _photos.length > 1;
                  return _PhotoTile(
                    url: url,
                    onDelete: canDelete ? () => _deletePhoto(url) : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
