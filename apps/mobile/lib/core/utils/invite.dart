import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Invitar a alguien a la app.
///
/// El agujero que tapa: MatchPoint sólo sirve si hay **otra** persona con tu
/// nivel y tu horario a menos de x km, y hasta ahora la app no ofrecía ninguna
/// forma de que alguien trajera a un conocido. Todo el crecimiento dependía de
/// que la descubrieran por su cuenta — en un producto cuyo problema es
/// exactamente la densidad local, eso es dejar la única palanca sin montar.
///
/// Está en dos sitios a propósito: en Ajustes (donde se busca) y en la lista
/// vacía de Descubrir (donde de verdad hace falta — el momento en que alguien
/// comprueba que no hay nadie por su zona es justo cuando tiene un motivo para
/// traer a alguien).
class Invite {
  Invite._();

  /// A dónde apunta el enlace del mensaje.
  ///
  /// Va por `--dart-define` porque hoy hay dos formas de repartir la app y las
  /// dos son legítimas: la ficha de la tienda cuando esté publicada, y un
  /// enlace a un APK mientras se enseña en clubes. Cambiar de una a otra tiene
  /// que ser un parámetro de compilación, no una versión nueva del código.
  ///
  /// **Vacío por defecto, y tiene que seguir estándolo.** Aquí hubo una URL de
  /// Google Play construida a partir del `applicationId` dando por hecho que
  /// esa ficha sería la nuestra. No lo era: `com.matchpoint.app` ya está
  /// ocupado en Play por otra app, así que el botón de invitar mandaba a la
  /// gente a descargar la de otro. Un enlace inventado es peor que no tener
  /// enlace, porque nadie lo comprueba hasta que ya se lo ha mandado a un
  /// conocido.
  static const url = String.fromEnvironment('INVITE_URL');

  static bool get hasUrl => url.isNotEmpty;

  /// Sin enlace configurado el mensaje sigue sirviendo: quien lo recibe está
  /// hablando contigo, y "pásame el enlace" es una respuesta normal. Lo que no
  /// puede pasar es que lleve a una app que no es la tuya.
  static String get message {
    const texto =
        '¿Jugamos? Estoy usando MatchPoint, una app para encontrar con quién '
        'jugar al tenis cerca de casa y a las horas que te vienen bien.';
    return hasUrl ? '$texto\n\n$url' : texto;
  }

  /// Abre el menú de compartir del sistema.
  ///
  /// `sharePositionOrigin` no es opcional en iPad: sin él, el popover no sabe
  /// de dónde salir y la llamada revienta. Se saca del propio widget que la
  /// dispara, así que basta con pasar su `context`.
  static Future<void> share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'MatchPoint',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}
