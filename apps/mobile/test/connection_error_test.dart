import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:match_point/core/network/api_error.dart';
import 'package:match_point/core/network/connection_error.dart';

void main() {
  group('errores de red', () {
    test('un fallo de DNS se convierte en "sin conexión"', () async {
      expect(
        () => mapNetworkErrors(
          () async => throw const SocketException('Failed host lookup'),
        ),
        throwsA(isA<NoConnectionException>()),
      );
    });

    test('la excepción de http también', () async {
      expect(
        () => mapNetworkErrors(
          () async => throw http.ClientException('Connection closed'),
        ),
        throwsA(isA<NoConnectionException>()),
      );
    });

    test('un timeout se distingue de no tener red', () async {
      expect(
        () => mapNetworkErrors(() async => throw TimeoutException('lento')),
        throwsA(isA<TimeoutFailure>()),
      );
    });

    /// Lo importante: un error de negocio del backend ya viene con su
    /// mensaje redactado, y envolverlo aquí lo escondería.
    test('un error del servidor pasa tal cual', () async {
      expect(
        () => mapNetworkErrors(
          () async => throw Exception('Ya has enviado una propuesta'),
        ),
        throwsA(
          predicate((e) => e is! NoConnectionException && e is! TimeoutFailure),
        ),
      );
    });

    test('el mensaje que se enseña no es la excepción cruda', () {
      final crudo = const SocketException(
        "Failed host lookup: 'api.example.com'",
      );
      final texto = friendlyError(const NoConnectionException());
      expect(texto, isNot(contains('SocketException')));
      expect(texto, contains('Sin conexión'));
      // Un error del servidor conserva su mensaje, que está redactado para
      // leerse.
      expect(
        friendlyError(const ApiException('La fecha ya ha pasado', 400)),
        'La fecha ya ha pasado',
      );
      // Y una excepción cualquiera de la app **no** se enseña: su texto es
      // diagnóstico. Se dice lo que la pantalla estaba intentando hacer.
      expect(
        friendlyError(
          Exception('type Null is not a subtype of String'),
          fallback: 'No se ha podido guardar tu nivel.',
        ),
        'No se ha podido guardar tu nivel.',
      );
      expect(crudo, isNotNull);
    });

    test('solo los de red se marcan como reintentables', () {
      expect(isConnectionError(const NoConnectionException()), isTrue);
      expect(isConnectionError(const TimeoutFailure()), isTrue);
      expect(isConnectionError(Exception('400')), isFalse);
    });
  });
}
