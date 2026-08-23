import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_error.dart';

/// La app no ha podido hablar con el servidor.
///
/// Existe porque, sin esto, cada pantalla enseñaba lo que devolvía
/// `e.toString()` de la excepción cruda: cosas como
/// `ClientException with SocketException: Failed host lookup: '...'`. Eso no
/// le dice nada a nadie, y encima suena a que la app está rota cuando lo
/// único que pasa es que el móvil ha entrado en un ascensor.
///
/// Es un tipo propio y no un mensaje suelto para que las pantallas puedan
/// distinguirlo de un error real del servidor: un fallo de red se reintenta,
/// un 400 no.
class NoConnectionException implements Exception {
  final String message;
  const NoConnectionException([
    this.message = 'Sin conexión. Comprueba tu red e inténtalo de nuevo.',
  ]);

  @override
  String toString() => message;
}

/// El servidor no contestó a tiempo.
///
/// Se distingue de no tener red porque la salida es distinta: aquí el móvil
/// sí tiene conexión, así que reintentar tiene sentido casi siempre.
class TimeoutFailure implements Exception {
  final String message;
  const TimeoutFailure([
    this.message = 'El servidor está tardando demasiado. Inténtalo de nuevo.',
  ]);

  @override
  String toString() => message;
}

/// Convierte los fallos de transporte en algo que se puede enseñar.
///
/// Se deja pasar cualquier otra excepción tal cual: un error de negocio del
/// backend ya viene con su mensaje redactado, y envolverlo aquí lo
/// escondería.
Future<T> mapNetworkErrors<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on SocketException {
    throw const NoConnectionException();
  } on http.ClientException {
    // Es lo que lanza `package:http` en web y, envolviendo a
    // `SocketException`, también en móvil.
    throw const NoConnectionException();
  } on TimeoutException {
    throw const TimeoutFailure();
  }
}

/// Mensaje presentable de cualquier error.
///
/// Las pantallas ya hacían `e.toString().replaceFirst('Exception: ', '')` cada
/// una por su cuenta; esto lo centraliza y de paso trata los de red.
String friendlyError(Object error, {String? fallback}) {
  if (error is NoConnectionException || error is TimeoutFailure) {
    return error.toString();
  }
  if (error is ApiException) {
    // El backend redacta sus 4xx pensando en que se lean; los 5xx llegan ya
    // convertidos en una frase genérica por `http_error.rs`.
    return error.message;
  }
  // Cualquier otra excepción es un fallo interno de la app: su texto es
  // diagnóstico, no un mensaje. Se enseña lo que la pantalla sepa decir de
  // lo que estaba intentando, y si no sabe, una frase honesta.
  return fallback ??
      'No se ha podido completar la operación. Inténtalo de '
          'nuevo en unos segundos.';
}

/// Si merece la pena ofrecer "Reintentar" con el mismo botón grande: un
/// problema de red se arregla solo en cuanto vuelve la cobertura, un error
/// del servidor probablemente no.
bool isConnectionError(Object error) =>
    error is NoConnectionException || error is TimeoutFailure;
