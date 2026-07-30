import 'package:flutter/material.dart';

import '../../profile/photo_grid_editor.dart';

/// Último paso del onboarding: subir al menos 1 foto antes de poder
/// entrar a la app. A diferencia del resto de pasos, este es obligatorio
/// — el botón "Comenzar" del wizard permanece deshabilitado hasta que
/// `photos` deja de estar vacío (lo controla `OnboardingProfileScreen`).
class OnboardingPhotoStep extends StatelessWidget {
  final List<String> photos;
  final bool busy;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

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
            photos: photos,
            busy: busy,
            onAdd: onAdd,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}
