import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/landscape_crop.dart';
import '../../profile/avatar_gallery.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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
/// entrada y elegir es un toque. Se puede saltar, y quien lo haga se lleva uno
/// igualmente (ver `_fallbackAvatar` en `onboarding_profile_screen.dart`):
/// saltar no puede significar quedarse fuera de Descubrir sin enterarse.
///
/// Y **la foto propia se pone aquí**, no sólo después desde Ajustes. Durante
/// un tiempo no se pudo: el paso ofrecía la rejilla y nada más, mientras el
/// texto de arriba pedía una foto — pedía algo que la pantalla no dejaba
/// hacer. El botón va por delante de la rejilla porque una cara de verdad es
/// lo que hace que otra persona acepte quedar; los avatares siguen debajo
/// porque son lo que evita que alguien abandone justo aquí.
class OnboardingAvatarStep extends StatelessWidget {
  /// El avatar ya elegido, si lo hay — se pinta marcado.
  final String? selectedAsset;
  final ValueChanged<String> onSelect;

  /// La foto propia ya elegida y recortada, si la hay.
  ///
  /// Foto y avatar son **excluyentes**: elegir una cosa borra la otra. Sólo
  /// se sube una imagen al crear la cuenta, así que dejar las dos marcadas a
  /// la vez obligaría a inventar cuál gana, y quien mirase la pantalla no
  /// sabría con cuál se va a quedar.
  final Uint8List? photoBytes;
  final VoidCallback onPickPhoto;
  final VoidCallback onClearPhoto;

  const OnboardingAvatarStep({
    super.key,
    required this.selectedAsset,
    required this.onSelect,
    required this.photoBytes,
    required this.onPickPhoto,
    required this.onClearPhoto,
  });

  /// La foto elegida, con su recorte real y un botón para quitarla.
  Widget _chosenPhoto(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AspectRatio(
            aspectRatio: kPhotoAspectRatio,
            child: Image.memory(photoBytes!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: scheme.surface.withValues(alpha: 0.85),
            shape: const CircleBorder(),
            child: IconButton(
              iconSize: 20,
              tooltip: S.current.delete,
              onPressed: onClearPhoto,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El paso pedía "elige tu avatar" y mencionaba la foto de pasada,
          // que es exactamente al revés de lo que le sirve a la app: una
          // ficha con la cara de alguien es lo que hace que otra persona
          // acepte quedar. El avatar sigue estando —es lo que evita que
          // alguien abandone aquí, que es donde se abandona— pero como
          // salida, no como opción principal.
          Text(S.current.chooseYourAvatar, style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            S.current.avatarHint,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // La foto propia, que **no se podía poner desde aquí**: el paso
          // ofrecía sólo la rejilla de avatares y subir una foto era algo
          // que había que descubrir después, en Ajustes. Con el texto de
          // arriba pidiendo una foto, faltaba el sitio por donde hacerlo.
          //
          // Ocupa el ancho entero y va por delante de la rejilla porque es
          // lo que se pide; los avatares siguen debajo, que es lo que evita
          // que alguien abandone en este paso.
          SizedBox(
            width: double.infinity,
            child: photoBytes == null
                ? OutlinedButton.icon(
                    onPressed: onPickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(S.current.addPhoto),
                  )
                : _chosenPhoto(context),
          ),

          const SizedBox(height: 20),
          Text(
            S.current.orPickAnAvatar,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

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
