import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/landscape_crop.dart';
import '../../profile/avatar_gallery.dart';

/// Último paso del registro: elegir un avatar.
///
/// Antes era "Sube tus fotos" y era **obligatorio** — el botón de terminar
/// seguía deshabilitado hasta que hubiera al menos una foto, porque un perfil
/// sin foto no sale en Descubrir. Es el punto donde más gente se caía: buscar
/// una foto decente en la galería, recortarla y subirla es mucho pedir a
/// alguien que todavía no ha visto para qué sirve la app. La escapatoria (los
/// avatares) existía, pero vivía dentro de una hoja, detrás de un botón que
/// decía "añadir foto".
///
/// Ahora la escapatoria **es** el paso: las seis ilustraciones se ven de
/// entrada, elegir es un toque, y subir una foto propia es algo que se hace
/// después desde el perfil, cuando ya hay motivo. Se puede saltar, y quien lo
/// haga se lleva uno igualmente (ver `_fallbackAvatar` en
/// `onboarding_profile_screen.dart`): saltar no puede significar quedarse
/// fuera de Descubrir sin enterarse.
class OnboardingAvatarStep extends StatelessWidget {
  /// El avatar ya elegido, si lo hay — se pinta marcado.
  final String? selectedAsset;
  final ValueChanged<String> onSelect;

  const OnboardingAvatarStep({
    super.key,
    required this.selectedAsset,
    required this.onSelect,
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
          Text('Elige tu avatar', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Si prefieres una foto tuya, '
            'puedes subirla más adelante desde tu perfil.',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: kPhotoAspectRatio,
            ),
            itemCount: kAvatarAssets.length,
            itemBuilder: (context, i) {
              final asset = kAvatarAssets[i];
              final selected = asset == selectedAsset;
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => onSelect(asset),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.asset(asset, fit: BoxFit.cover),
                    ),
                    if (selected)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: scheme.primary, width: 3),
                          color: scheme.primary.withValues(alpha: 0.22),
                        ),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.check_circle,
                              color: scheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
