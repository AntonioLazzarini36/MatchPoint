/// Cómo llegar a la información para **reservar** la pista.
///
/// El problema que resuelve: MatchPoint no reserva nada. Acordar una quedada
/// en la app es acordarla entre dos personas, y la pista sigue sin alquilar.
/// No hay convenio con ningún club, no sabemos si queda hueco a esa hora, y
/// casi nunca sabemos su web — `TennisClub.website` sale de la etiqueta
/// `website` de OpenStreetMap y estaba medido: **0 de 40 clubes** la tenían.
///
/// Así que el enlace fiable no es la web del club: es su ficha de Google
/// Maps, donde sí están el teléfono, la web y el horario de casi cualquier
/// negocio. De ahí que se construya a partir de lo que una propuesta **sí**
/// guarda siempre — nombre del sitio y/o coordenadas.
library;

/// Enlace de Google Maps para un sitio del que sabemos nombre, coordenadas o
/// las dos cosas. Devuelve null si no hay ni una cosa ni la otra.
String? clubMapsUrl({String? name, double? latitude, double? longitude}) {
  final hasCoords = latitude != null && longitude != null;
  final clean = name?.trim();
  final hasName = clean != null && clean.isNotEmpty;

  if (hasName && hasCoords) {
    // Nombre **y** centrado en sus coordenadas. Es la única de las tres
    // formas que da las dos cosas a la vez: buscar por nombre es lo que
    // encuentra la ficha del negocio (con su teléfono y su web, que es a lo
    // que se viene), y el `@lat,lng,zoom` evita que un nombre corriente
    // —"Club de Tenis"— acabe enseñando uno de otra provincia.
    return 'https://www.google.com/maps/search/'
        '${Uri.encodeComponent(clean)}/@$latitude,$longitude,15z';
  }
  if (hasName) {
    return 'https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent(clean)}';
  }
  if (hasCoords) {
    // Sin nombre sólo se puede clavar el pin: no habrá ficha de negocio que
    // abrir, pero al menos se ve qué hay en ese punto.
    return 'https://www.google.com/maps/search/?api=1'
        '&query=$latitude,$longitude';
  }
  return null;
}

/// Enlace de Google Maps **al punto exacto**, ignorando cualquier nombre.
///
/// Es distinto de [clubMapsUrl] y la diferencia importa. Aquél busca por
/// nombre porque lo que quieres es la ficha del negocio, con su teléfono y su
/// web, que es a lo que se va desde "falta reservar la pista".
///
/// Aquí no: esto es para cuando alguien **marcó un punto en el mapa** porque
/// su sitio no salía en la lista de clubes. El nombre entonces es lo que
/// escribió a mano ("entrada del parque, junto a la fuente"), y buscar eso en
/// Maps lleva a cualquier parte menos al sitio. Lo único fiable es el par de
/// coordenadas que se guardó.
String mapsPinUrl(double latitude, double longitude) =>
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
