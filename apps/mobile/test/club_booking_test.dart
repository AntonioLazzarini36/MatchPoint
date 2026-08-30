import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/utils/club_booking.dart';

/// El enlace que se le ofrece a alguien para ir a reservar la pista. Se
/// prueba porque es la única salida que tiene esa pantalla hacia el club, y
/// un enlace mal formado no falla: abre Maps enseñando otra cosa.
void main() {
  test('con nombre y coordenadas busca el nombre, pero centrado ahí', () {
    final url = clubMapsUrl(
      name: 'Club de Tenis Benalmádena',
      latitude: 36.5987,
      longitude: -4.5169,
    );
    // El nombre es lo que encuentra la ficha del negocio (teléfono y web);
    // las coordenadas evitan que un nombre corriente saque otra provincia.
    expect(url, contains('Club%20de%20Tenis%20Benalm'));
    expect(url, contains('@36.5987,-4.5169,15z'));
  });

  test('sólo con nombre, busca el nombre', () {
    final url = clubMapsUrl(name: 'Club de Tenis Málaga');
    expect(url, startsWith('https://www.google.com/maps/search/?api=1'));
    expect(url, contains('query=Club%20de%20Tenis%20M'));
  });

  test('sólo con coordenadas, clava el pin', () {
    final url = clubMapsUrl(latitude: 36.72, longitude: -4.42);
    expect(url, contains('query=36.72,-4.42'));
  });

  test('sin nada que ofrecer, no hay enlace', () {
    // Devolver una URL a medias sería peor: el botón existiría y llevaría a
    // ninguna parte.
    expect(clubMapsUrl(), isNull);
    expect(clubMapsUrl(name: '   '), isNull);
  });
}
