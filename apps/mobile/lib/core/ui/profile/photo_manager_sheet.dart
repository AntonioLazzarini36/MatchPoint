import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../features/onboarding/services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'photo_grid_editor.dart';
import 'photo_crop_preview.dart';

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

  /// Varias fotos de una tacada: el selector permite marcar todas las que
  /// quepan, se recortan y se previsualizan juntas, y luego se suben una
  /// detrás de otra (el endpoint acepta una por peticion).
  Future<void> _addPhotos() async {
    final remaining = PhotoGridEditor.maxPhotos - _photos.length;
    if (remaining <= 0) {
      setState(() => _error = 'Máximo ${PhotoGridEditor.maxPhotos} fotos.');
      return;
    }

    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      // El propio selector impide pasarse, en vez de dejar elegir 6 y
      // luego decir que no caben.
      limit: remaining,
    );
    if (picked.isEmpty || !mounted) return;

    final originals = <Uint8List>[];
    for (final file in picked) {
      originals.add(await file.readAsBytes());
    }
    if (!mounted) return;

    // Mismo recorte a 16:9 con vista previa que en el onboarding — las
    // fotos tienen que verse igual se suban desde donde se suban.
    final cropped = await showPhotoCropPreview(context, originals: originals);
    if (cropped == null || cropped.isEmpty || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      for (final bytes in cropped) {
        final profile = await widget.service.uploadPhoto(
          bytes: bytes,
          // El recorte re-codifica a PNG (ver landscape_crop.dart).
          filename: '${DateTime.now().microsecondsSinceEpoch}.png',
          contentType: 'image/png',
        );
        if (!mounted) return;
        setState(() => _photos = profile.photos);
      }
      widget.onChanged(_photos);
    } catch (e) {
      if (!mounted) return;
      // Puede haber subido algunas antes de fallar: el estado ya refleja
      // lo que el backend tiene, así que basta con contarlo.
      setState(() => _error = 'No se pudieron subir todas las fotos: $e');
      widget.onChanged(_photos);
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
              photos: _photos.map(RemotePhoto.new).toList(),
              busy: _busy,
              onAdd: _addPhotos,
              onDelete: (i) => _deletePhoto(_photos[i]),
            ),
          ],
        ),
      ),
    );
  }
}
