/// Un grupo de pistas de tenis cercanas, tratado como un club/instalación
/// en el mapa. OSM apenas etiqueta clubes de verdad en España
/// (`leisure=sports_centre` + `sport=tennis` devuelve casi nada usable),
/// pero las pistas sueltas (`leisure=pitch` + `sport=tennis`) sí están bien
/// mapeadas y las de un mismo club están físicamente juntas — así que
/// `OverpassService` pide ambas cosas y agrupa por cercanía.
class TennisClub {
  final String id;

  /// Lo que se muestra y lo que acaba guardado como sitio de la propuesta.
  /// Ojo: puede ser un nombre genérico — ver [hasRealName].
  final String name;

  /// False cuando ningún elemento del grupo traía etiqueta `name` en OSM y
  /// [name] es un relleno ("Pistas de tenis"). Importa porque mandarle a
  /// alguien "Club de tenis" a secas no le dice dónde tiene que aparecer:
  /// quien elige uno de estos tiene que poder ponerle nombre a mano.
  final bool hasRealName;

  /// Calle (y número, si lo hay) de las etiquetas `addr:*`, cuando existen.
  /// Sirve para distinguir dos grupos sin nombre en la misma zona sin
  /// gastar una petición de geocodificación inversa por cada uno.
  final String? street;

  final int courtCount;
  final double latitude;
  final double longitude;

  /// De la etiqueta `website` de OSM, si algún elemento del grupo la tiene
  /// — en la práctica casi nunca (0/40 comprobados cerca de Madrid), así
  /// que es un extra oportunista, no algo con lo que contar. El enlace de
  /// Google Maps construido con lat/lng es el fiable.
  final String? website;

  const TennisClub({
    required this.id,
    required this.name,
    required this.courtCount,
    required this.latitude,
    required this.longitude,
    this.hasRealName = true,
    this.street,
    this.website,
  });

  /// Para la cache en disco de `OverpassService`.
  ///
  /// Formato propio y no el JSON crudo de Overpass: lo que se guarda es el
  /// resultado ya agrupado y con nombre resuelto, que es una fraccion del
  /// tamaño y ahorra repetir todo el trabajo de agrupacion al leerlo.
  Map<String, dynamic> toCache() => {
    'id': id,
    'name': name,
    'real': hasRealName,
    'street': street,
    'courts': courtCount,
    'lat': latitude,
    'lng': longitude,
    'web': website,
  };

  factory TennisClub.fromCache(Map<String, dynamic> json) => TennisClub(
    id: json['id'].toString(),
    name: (json['name'] ?? '').toString(),
    hasRealName: json['real'] == true,
    street: json['street']?.toString(),
    courtCount: (json['courts'] as num?)?.toInt() ?? 0,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    website: json['web']?.toString(),
  );
}
