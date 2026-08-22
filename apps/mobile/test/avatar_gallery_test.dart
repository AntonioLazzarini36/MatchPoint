import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/ui/profile/avatar_gallery.dart';
import 'package:match_point/core/utils/landscape_crop.dart';

void main() {
  // Sin esto `rootBundle` no tiene de dónde leer en un test.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada avatar existe y sale como una foto válida para subir', () async {
    expect(kAvatarAssets, hasLength(6));

    for (final asset in kAvatarAssets) {
      final bytes = await loadAvatarBytes(asset);

      // El backend olfatea los bytes en vez de fiarse del content-type, así
      // que si esto dejara de ser un PNG el avatar se rechazaría al subir.
      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ], reason: '$asset no sale como PNG');

      // Y por encima de 5 MB el backend lo rechaza por tamaño.
      expect(bytes.lengthInBytes, lessThan(5 * 1024 * 1024), reason: asset);

      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final ratio = image.width / image.height;
      expect(
        ratio,
        closeTo(kPhotoAspectRatio, 0.01),
        reason: '$asset no queda en 16:9',
      );
      image.dispose();
    }
  });
}
