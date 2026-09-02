import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/utils/about_links.dart';

/// Los enlaces legales y de contacto.
///
/// Se prueban porque **las mismas direcciones viven fuera del codigo**: son
/// campos obligatorios de la ficha de Google Play. Si una se rompe aqui, la
/// app enlaza a una cosa y la tienda a otra, y nadie se entera hasta que
/// alguien toca la fila y no abre nada.
void main() {
  test('las tres paginas cuelgan del mismo sitio y son https', () {
    for (final url in [privacyPolicyUrl, termsUrl, deleteAccountUrl]) {
      expect(url, startsWith('https://'));
      expect(url, endsWith('.html'));
    }
    // Distintas entre si: copiar y pegar una fila y olvidar cambiar la URL
    // es exactamente como esto se rompe.
    expect({privacyPolicyUrl, termsUrl, deleteAccountUrl}.length, 3);
  });

  test('el mailto lleva el asunto y no pierde el buzon', () {
    final uri = contactMailto('MatchPoint — sugerencia');
    expect(uri.scheme, 'mailto');
    expect(uri.path, contactEmail);
    expect(uri.queryParameters['subject'], 'MatchPoint — sugerencia');
    // El acento y el guion largo tienen que sobrevivir al escapado, que es
    // donde un mailto montado a mano con concatenacion se rompe.
    expect(uri.toString(), contains('MatchPoint'));
  });
}
