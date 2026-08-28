import '../../features/discovery/models/sport.dart';

/// Qué deportes ofrece la app **hoy**.
///
/// MatchPoint nació con tenis y running a la vez, y eso salía caro en todas
/// las pantallas: un paso de registro para elegir deporte, un vocabulario
/// neutro ("quedada") que no es como habla nadie, campos de experiencia condicionales
/// (años/club contra ritmo/distancia), filtros por deporte, y un icono de
/// deporte en cada tarjeta para desambiguar. Todo eso es trabajo que sólo
/// tiene sentido cuando de verdad hay dos públicos — y con la app vacía no
/// hay ninguno. Dos deportes a medias también parten en dos la densidad, que
/// es justo lo único que hace que la app funcione.
///
/// **Running no se ha borrado, se ha apagado.** El enum `Sport`, la columna
/// `Profile.sports`, el filtro `?sport=` del backend y las quedadas de correr
/// siguen existiendo enteros: volver a encenderlo es añadir `Sport.running`
/// a esta lista. Borrarlo habría significado una migración destructiva para
/// deshacer una decisión de producto que puede cambiar.
///
/// Todo lo que pregunte "¿hay que enseñar el deporte?" debe mirar
/// [singleSport] en vez de comparar contra `Sport.tennis` a pelo, para que
/// encender el segundo deporte sea un cambio de una línea y no una caza por
/// toda la app.
const List<Sport> enabledSports = [Sport.tennis];

/// El único deporte, cuando sólo hay uno — y `null` cuando hay varios.
///
/// Con un solo deporte, decirlo en la interfaz es ruido: un chip "Tenis" en
/// cada tarjeta de una app de tenis no distingue nada de nada. El nombre, el
/// logo y el propio icono de la app ya lo dicen. Cuando devuelve `null` hay
/// que volver a mostrarlo en todas partes.
Sport? get singleSport => enabledSports.length == 1 ? enabledSports.first : null;

/// `true` mientras la app sea de un solo deporte. Azúcar sobre
/// [singleSport], para las condiciones que no necesitan saber cuál es.
bool get isSingleSportApp => singleSport != null;

/// Recorta una lista de deportes a los que la app ofrece hoy.
///
/// Hace falta porque hay cuentas creadas cuando se podía elegir running: su
/// `Profile.sports` puede traer un deporte que la app ya no enseña, y sin
/// este filtro pedirían un feed de un deporte que no existe en la interfaz.
List<Sport> onlyEnabled(Iterable<Sport> sports) {
  final kept = sports.where(enabledSports.contains).toList();
  return kept.isEmpty ? enabledSports : kept;
}
