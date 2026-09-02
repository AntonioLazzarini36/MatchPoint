import 'package:match_point/core/i18n/app_locale.dart';
/// Cómo se dice una distancia en la interfaz.
///
/// Por debajo de 1 km el decimal es ruido ("a 0,4 km" no cambia ninguna
/// decisión); por encima, un entero basta. Vive suelto y no dentro de una
/// tarjeta para que la misma persona no salga "a 3 km" en un sitio y "a 2,8
/// km" en otro — estaba en `discovery_mini_card.dart`, que desapareció al
/// quitar el mazo de tarjetas de Discovery.
String distanceLabel(double km) => km < 1 ? S.current.veryClose : S.current.kmAway('${km.round()}');
