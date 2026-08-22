import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../theme/app_theme.dart';
import '../../utils/landscape_crop.dart';

/// Las ilustraciones que trae la app para quien no quiere poner una foto
/// suya el primer día.
///
/// Existen porque el registro obliga a tener al menos una foto — sin ella
/// `/discover` no enseña el perfil — y ese requisito, puesto delante de
/// alguien que acaba de instalar la app, es donde más gente se cae: buscar
/// una foto decente en la galería es mucho pedir antes de haber visto para
/// qué sirve esto.
const kAvatarAssets = <String>[
  'assets/avatars/character1.jpg',
  'assets/avatars/character2.jpg',
  'assets/avatars/character3.jpg',
  'assets/avatars/character4.jpg',
  'assets/avatars/character5.jpg',
  'assets/avatars/character6.jpg',
];

/// Deja elegir una ilustración. Devuelve la ruta del asset, o null si se
/// cierra sin elegir.
Future<String?> pickAvatar(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Elige un avatar', style: sheetContext.textStyles.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Puedes cambiarlo por una foto tuya cuando quieras, desde tu '
              'perfil.',
              style: sheetContext.textStyles.bodySmall?.copyWith(
                color: sheetContext.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: kPhotoAspectRatio,
                ),
                itemCount: kAvatarAssets.length,
                itemBuilder: (context, i) {
                  final asset = kAvatarAssets[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(sheetContext).pop(asset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(asset, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Los bytes de un avatar, listos para subir.
///
/// Pasa por el mismo recorte a 16:9 que una foto de la galería aunque las
/// ilustraciones ya vengan apaisadas: así todo lo que sube la app tiene
/// exactamente la misma proporción y el mismo formato, y no hay un segundo
/// camino que mantener cuando cambie el recorte.
Future<Uint8List> loadAvatarBytes(String asset) async {
  final data = await rootBundle.load(asset);
  return cropToLandscape(data.buffer.asUint8List());
}
