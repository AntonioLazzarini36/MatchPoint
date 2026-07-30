import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../profile/photo_grid_editor.dart';

/// Último paso del onboarding: elegir al menos 1 foto antes de poder
/// entrar a la app. Las fotos aquí son solo bytes en memoria — no se
/// suben hasta el "Comenzar" final, junto con el resto del registro (ver
/// `OnboardingProfileScreen`). A diferencia del resto de pasos, este es
/// obligatorio: el botón "Comenzar" permanece deshabilitado hasta que
/// `photos` deja de estar vacío.
class OnboardingPhotoStep extends StatelessWidget {
  final List<Uint8List> photos;
  final bool busy;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;

  const OnboardingPhotoStep({
    super.key,
    required this.photos,
    required this.busy,
    required this.error,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sube tus fotos', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Añade al menos una foto haciendo tus deportes para que los '
            'demás vean con quién van a jugar.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (error != null) ...[
            Text(error!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
          ],
          PhotoGridEditor(
            photos: photos.map(LocalPhoto.new).toList(),
            busy: busy,
            onAdd: onAdd,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}
