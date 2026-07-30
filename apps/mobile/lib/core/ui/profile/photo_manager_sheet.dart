import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../features/onboarding/services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'photo_grid_editor.dart';

/// Bottom sheet para gestionar las fotos del propio perfil: grid de fotos
/// actuales + tile para añadir (abre el selector de imagen) + borrar por
/// foto. Usado desde `ProfileScreen` para editar el perfil ya creado — el
/// paso de subir la primera foto durante el onboarding es una página propia
/// del wizard (`OnboardingPhotoStep`), no este sheet.
class PhotoManagerSheet extends StatefulWidget {
  final ProfileService service;
  final List<String> initialPhotos;
  final ValueChanged<List<String>> onChanged;

  const PhotoManagerSheet({
    super.key,
    required this.service,
    required this.initialPhotos,
    required this.onChanged,
  });

  @override
  State<PhotoManagerSheet> createState() => _PhotoManagerSheetState();
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
    if (_photos.length >= PhotoGridEditor.maxPhotos) {
      setState(() => _error = 'Máximo ${PhotoGridEditor.maxPhotos} fotos.');
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
        contentType: picked.mimeType ?? guessPhotoContentType(picked.name),
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
    return SafeArea(
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: context.colors.error)),
            ],
            const SizedBox(height: 12),
            PhotoGridEditor(
              photos: _photos,
              busy: _busy,
              onAdd: _addPhoto,
              onDelete: _deletePhoto,
            ),
          ],
        ),
      ),
    );
  }
}
