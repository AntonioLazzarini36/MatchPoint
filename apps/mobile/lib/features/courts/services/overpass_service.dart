import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../models/tennis_club.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Un elemento de OSM ya normalizado: o una pista suelta, o la instalación
/// que la contiene (polideportivo, club, complejo deportivo).
class _Element {
  final String id;
  final String? name;
  final String? website;
  final String? street;

  /// Valor crudo de la etiqueta `sport`. Puede ser compuesto
  /// (`swimming;padel;futsal`) o faltar por completo.
  final String? sport;

  /// `leisure=sports_centre` o cualquier `club=*`: la instalación entera,
  /// no una pista.
  final bool isFacility;

  final double lat;
  final double lon;

  const _Element({
    required this.id,
    required this.name,
    required this.website,
    required this.street,
    required this.sport,
    required this.isFacility,
    required this.lat,
    required this.lon,
  });
}

/// Consulta Overpass (la API de consultas de OpenStreetMap, sin API key)
/// buscando pistas de tenis reales cerca de un punto y las agrupa en
/// clubes — ver el comentario de [TennisClub]. Es una API de terceros, no
/// nuestro backend, así que va con `http` pelado en vez de `ApiClient`.
///
/// **De dónde sale el nombre del club.** Las pistas (`leisure=pitch`) casi
/// nunca llevan etiqueta `name`, así que el nombre hay que buscarlo en la
/// instalación que las contiene. Y ahí estaba el fallo de la primera
/// versión: pedía `sports_centre` *exigiendo* `sport~tennis`, pero en OSM
/// la mayoría de complejos no llevan etiqueta `sport` — "Club de Tenis
/// Capellanía" existe mapeado y quedaba fuera por eso. Ahora se piden
/// **todas** las instalaciones de la zona y se le pega su nombre al grupo
/// de pistas que tengan al lado. Medido cerca de Benalmádena: de 0 clubes
/// con nombre a 17, incluidos los grandes (Lew Hoad 8 pistas, Complejo
/// Tenis Málaga 7, Algarrobo 5).
class OverpassService {
  // Sólo espejos comprobados a mano que devuelven datos completos y
  // correctos — algunos responden rápido pero con el dataset vacío o
  // caducado (overpass.osm.ch devolvía 0 resultados para una consulta con
  // 40 coincidencias reales), que es peor que un timeout honesto porque
  // diría "no hay clubes" habiéndolos.
  //
  // El orden importa mucho más de lo que parece: los espejos se prueban de
  // uno en uno, así que uno caído al principio de la lista se paga en cada
  // búsqueda antes de llegar al siguiente.
  //
  // Kumi Systems estaba primero y **está caído** (502, y a ratos se queda
  // colgado hasta agotar el tiempo — medido el 2026-08-28). Con el tiempo de
  // espera de 25 s que había, cada búsqueda tardaba medio minuto largo en
  // llegar a un servidor sano: quien esperaba veía los clubes y quien se
  // cansaba concluía que no funcionaban. De ahí el "a veces sí y a veces no".
  //
  // Ahora van primero los dos que responden (1-2 s, 194 sitios cerca de
  // Benalmádena, comprobado), Kumi queda de último recurso, y `_preferred`
  // se queda con el que haya funcionado para no volver a pagar la ronda.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Cuánto se espera a un espejo antes de pasar al siguiente.
  ///
  /// 20 s, y el número tiene historia. Estaba en 25, lo bajé a 8 al ver que
  /// el primer espejo de la lista estaba caído... y eso rompió el caso
  /// contrario. Medido el 2026-08-28 contra `overpass-api.de`:
  ///
  ///   radio de 10 km, 1ª petición ....... 0,9 s
  ///   la misma, 2ª seguida .............. 2,6 s
  ///   la misma, 3ª seguida .............. 7,2 s
  ///   radio de 30 km ("ampliar") ........ 6,0 s
  ///
  /// Overpass es gratuito y compartido: **encola por IP y va frenando a quien
  /// insiste**. O sea que justo cuando alguien reintenta porque le ha
  /// fallado, las respuestas tardan más — y con 8 s se cortaban solas. Eso
  /// convertía un fallo puntual en una bola de nieve: fallo → reintento →
  /// más lento → fallo.
  ///
  /// Un espejo muerto no necesita este plazo (contesta 502 en 4 s), así que
  /// esperar más no cuesta nada en ese caso; lo que arregla el problema de
  /// verdad es el orden de la lista, no recortar el tiempo.
  static const _perEndpointTimeout = Duration(seconds: 20);

  /// El último espejo que funcionó en esta sesión. Se prueba el primero: sin
  /// esto, cada búsqueda nueva vuelve a empezar por el principio de la lista
  /// y a pagar los que estén caídos.
  static String? _preferred;

  /// Pistas más cerca que esto entre sí son del mismo sitio.
  static const _clusterRadiusMeters = 150.0;

  /// Una instalación con nombre a menos de esto de un grupo de pistas es
  /// el nombre de ese grupo. Más generoso que el de agrupación porque un
  /// polideportivo es grande y `out center` da su centroide, que puede
  /// caer lejos de sus propias pistas.
  static const _facilityRadiusMeters = 300.0;

  /// Resultados ya pedidos en esta sesión, por (lat, lng, radio)
  /// redondeados. Estático a propósito: el mapa de clubes y el selector de
  /// sitio al proponer preguntan casi siempre por el mismo punto (tu
  /// ubicación de perfil), así que sin esto cada entrada a cualquiera de
  /// los dos era otra consulta a un servicio público que se satura. Las
  /// pistas de una zona no cambian en lo que dura una sesión.
  static final Map<String, List<TennisClub>> _cache = {};

  /// La misma caché, pero en disco y sobreviviendo al cierre de la app.
  ///
  /// Es la pieza que más reduce los fallos, porque el problema de fondo no es
  /// la velocidad de Overpass sino **cuántas veces se le pregunta**: encola
  /// por IP, así que cada consulta que se ahorra hace más rápida la
  /// siguiente. Con la caché sólo en memoria, cerrar la app la vaciaba y la
  /// primera búsqueda del día volvía a pagar la cola entera.
  ///
  /// Las pistas de tenis de una zona no cambian de un día para otro: se
  /// guardan 7 días. Se reutiliza `flutter_secure_storage`, que ya está en el
  /// proyecto para tokens y flags, en vez de añadir un paquete nuevo sólo
  /// para esto (mismo criterio que `LocalFlags`).
  static const _storage = FlutterSecureStorage();
  static const _diskPrefix = 'overpass_clubs_';
  static const _diskTtl = Duration(days: 7);

  static Future<List<TennisClub>?> _readDisk(String key) async {
    try {
      final raw = await _storage.read(key: '$_diskPrefix$key');
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        decoded['at'] as int? ?? 0,
      );
      if (DateTime.now().difference(savedAt) > _diskTtl) return null;

      final clubs = (decoded['clubs'] as List<dynamic>)
          .map((e) => TennisClub.fromCache(e as Map<String, dynamic>))
          .toList();
      return clubs.isEmpty ? null : clubs;
    } catch (_) {
      // Un formato viejo o corrupto no puede tumbar la busqueda: se ignora y
      // se pregunta a la red, que es lo que se haria de todas formas.
      return null;
    }
  }

  static Future<void> _writeDisk(String key, List<TennisClub> clubs) async {
    try {
      await _storage.write(
        key: '$_diskPrefix$key',
        value: jsonEncode({
          'at': DateTime.now().millisecondsSinceEpoch,
          'clubs': clubs.map((c) => c.toCache()).toList(),
        }),
      );
    } catch (_) {
      // Sin caché en disco se sigue funcionando, solo que más lento.
    }
  }

  /// La clave de caché, **redondeada a una rejilla proporcional al radio**.
  ///
  /// Estaba a cuatro decimales, o sea ~11 m. Con una búsqueda de 10 km eso no
  /// cachea nada: dos puntos separados por una calle devuelven exactamente los
  /// mismos clubes y sin embargo eran dos consultas distintas. Y ahí está el
  /// problema de verdad, porque **Overpass limita por IP**: cada consulta de
  /// más acerca el 429, y cuando llega, la búsqueda siguiente no tarda — falla.
  ///
  /// Ahora la rejilla es de una décima parte del radio (1 km buscando a 10),
  /// así que moverse por la misma zona reutiliza lo ya pedido. El precio es
  /// que el centro puede estar hasta medio kilómetro desplazado del punto
  /// exacto, que con un radio de 10 km no cambia la lista.
  static String _cacheKey(double latitude, double longitude, int radiusMeters) {
    // Un grado de latitud son ~111 km en cualquier parte del mundo.
    final cellDegrees = (radiusMeters / 10) / 111000;
    String snap(double value) =>
        (value / cellDegrees).round().toString();
    return '${snap(latitude)},${snap(longitude)},$radiusMeters';
  }

  Future<List<TennisClub>> nearbyClubs({
    required double latitude,
    required double longitude,
    int radiusMeters = 10000,
  }) async {
    final key = _cacheKey(latitude, longitude, radiusMeters);
    final cached = _cache[key];
    if (cached != null) return cached;

    // Antes de molestar a Overpass, lo que se guardó en sesiones anteriores.
    final fromDisk = await _readDisk(key);
    if (fromDisk != null) {
      _cache[key] = fromDisk;
      return fromDisk;
    }

    // Nada de filtrar las instalaciones por `sport`: es justo la etiqueta
    // que les falta (ver el comentario de la clase). Se filtra después, ya
    // en local, mirando qué instalación tiene pistas de tenis al lado.
    //
    // Tampoco se busca por nombre (`name~"[Tt]enis"`): una regex sobre
    // nombres en un radio de 15 km hace que Overpass devuelva 504,
    // comprobado.
    final area = '(around:$radiusMeters,$latitude,$longitude)';
    final query =
        '[out:json][timeout:60];'
        '('
        'nwr["leisure"="pitch"]["sport"~"tennis"]$area;'
        'nwr["leisure"="sports_centre"]$area;'
        'nwr["club"]$area;'
        ');'
        'out center tags 400;';

    // El que funcionó la última vez, primero; el resto detrás, sin repetirlo.
    final ordered = <String>[
      ?_preferred,
      ..._endpoints.where((e) => e != _preferred),
    ];

    Object? lastError;
    for (final endpoint in ordered) {
      try {
        final res = await http
            .post(Uri.parse(endpoint), body: {'data': query})
            .timeout(_perEndpointTimeout);

        if (res.statusCode < 200 || res.statusCode >= 300) {
          lastError = Exception('$endpoint failed: ${res.statusCode}');
          continue;
        }

        final clubs = _buildClubs(_parse(res.body));

        // **Una respuesta vacía no se guarda en caché.** Un espejo con
        // problemas puede contestar 200 con cero elementos, y como la caché
        // no caduca en toda la sesión, ese vacío se quedaba pegado: a partir
        // de ahí el selector de clubes salía vacío al instante y no había
        // forma de recuperarlo sin cerrar la app. Es la otra mitad del "a
        // veces no funciona" — la mitad que además no se arreglaba sola.
        //
        // Que una zona no tenga pistas es posible, claro; pero volver a
        // preguntarlo cuesta una consulta y equivocarse cuesta la función
        // entera.
        if (clubs.isNotEmpty) {
          _cache[key] = clubs;
          _preferred = endpoint;
          await _writeDisk(key, clubs);
        }
        return clubs;
      } catch (e) {
        lastError = e;
        // Si el que venía marcado como bueno falla, deja de serlo.
        if (endpoint == _preferred) _preferred = null;
        continue;
      }
    }

    throw Exception('${S.current.allOverpassServersFailed}: $lastError');
  }

  List<_Element> _parse(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];

    return elements
        .map((e) {
          final m = e as Map<String, dynamic>;
          // Los nodos traen lat/lon directamente; los ways/relations sólo
          // los tienen vía `out center`, en un objeto `center` anidado.
          final center = m['center'] as Map<String, dynamic>?;
          final lat =
              (m['lat'] as num?)?.toDouble() ??
              (center?['lat'] as num?)?.toDouble();
          final lon =
              (m['lon'] as num?)?.toDouble() ??
              (center?['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) return null;

          final tags = m['tags'] as Map<String, dynamic>? ?? const {};
          String? tag(String key) {
            final value = (tags[key] as String?)?.trim();
            return (value == null || value.isEmpty) ? null : value;
          }

          final street = tag('addr:street');
          final houseNumber = tag('addr:housenumber');

          return _Element(
            id: '${m['type']}/${m['id']}',
            name: tag('name'),
            website: tag('website'),
            street: street == null
                ? null
                : (houseNumber == null ? street : '$street $houseNumber'),
            sport: tag('sport'),
            isFacility:
                tags['leisure'] == 'sports_centre' || tags.containsKey('club'),
            lat: lat,
            lon: lon,
          );
        })
        .whereType<_Element>()
        .toList();
  }

  /// ¿Puede el nombre de esta instalación describir unas pistas de tenis?
  ///
  /// Sin etiqueta `sport` sí: es el caso normal de un club o polideportivo
  /// mapeado a medias, y si tiene pistas de tenis pegadas es su nombre.
  /// Con `sport` puesto, sólo si menciona tenis o es multideporte — sin
  /// esto, unas pistas junto a "Karting Mijas" saldrían llamándose así, y
  /// un nombre equivocado es peor que ninguno.
  bool _canNameCourts(_Element facility) {
    if (facility.name == null) return false;
    final sport = facility.sport?.toLowerCase();
    if (sport == null) return true;
    return sport.contains('tennis') || sport == 'multi';
  }

  List<TennisClub> _buildClubs(List<_Element> elements) {
    final pitches = elements.where((e) => !e.isFacility).toList();
    final facilities = elements.where(_canNameCourts).toList();

    // Agrupación por cercanía, greedy: cada pista se une al primer grupo
    // cuyo primer miembro esté a menos de [_clusterRadiusMeters], o abre
    // uno nuevo. Suficiente para "estas son obviamente las pistas del
    // mismo sitio" — no pretende ser clustering general.
    final clusters = <List<_Element>>[];
    for (final pitch in pitches) {
      List<_Element>? target;
      for (final cluster in clusters) {
        final rep = cluster.first;
        if (_distanceMeters(rep.lat, rep.lon, pitch.lat, pitch.lon) <=
            _clusterRadiusMeters) {
          target = cluster;
          break;
        }
      }
      (target ?? (clusters..add(<_Element>[])).last).add(pitch);
    }

    final clubs = <TennisClub>[];
    // Un complejo grande puede quedar partido en varios grupos de pistas
    // (dos zonas separadas más de 150 m). Se fusionan por instalación para
    // no listar dos veces "Complejo Tenis Málaga".
    final byFacility = <String, TennisClub>{};

    for (final cluster in clusters) {
      final lat =
          cluster.map((c) => c.lat).reduce((a, b) => a + b) / cluster.length;
      final lon =
          cluster.map((c) => c.lon).reduce((a, b) => a + b) / cluster.length;

      final facility = _nearestFacility(facilities, lat, lon);
      final ownName = cluster
          .map((c) => c.name)
          .firstWhere((name) => name != null, orElse: () => null);
      final street = cluster
          .map((c) => c.street)
          .firstWhere((s) => s != null, orElse: () => null);
      final website = cluster
          .map((c) => c.website)
          .firstWhere((w) => w != null, orElse: () => null);

      // El nombre propio de la pista gana al del complejo: si alguien se
      // molestó en nombrar la pista, es más específico.
      final name = ownName ?? facility?.name;

      final club = TennisClub(
        id: cluster.first.id,
        name: name ?? _fallbackName(street),
        hasRealName: name != null,
        street: street ?? facility?.street,
        courtCount: cluster.length,
        latitude: lat,
        longitude: lon,
        website: website ?? facility?.website,
      );

      if (ownName == null && facility != null) {
        final merged = byFacility[facility.id];
        if (merged != null) {
          byFacility[facility.id] = TennisClub(
            id: merged.id,
            name: merged.name,
            hasRealName: merged.hasRealName,
            street: merged.street,
            courtCount: merged.courtCount + club.courtCount,
            latitude: merged.latitude,
            longitude: merged.longitude,
            website: merged.website,
          );
        } else {
          byFacility[facility.id] = club;
        }
      } else {
        clubs.add(club);
      }
    }

    clubs.addAll(byFacility.values);

    // Los sitios con nombre primero: son los clubes de verdad, y son los
    // únicos que la otra persona va a reconocer al recibir la propuesta.
    // Dentro de cada grupo, más pistas primero (un club de 8 pistas es más
    // probable que una pista suelta de urbanización).
    clubs.sort((a, b) {
      if (a.hasRealName != b.hasRealName) return a.hasRealName ? -1 : 1;
      return b.courtCount.compareTo(a.courtCount);
    });

    return clubs;
  }

  String _fallbackName(String? street) =>
      street == null
          ? S.current.tennisCourtsGeneric
          : S.current.tennisCourtsAt(street);

  _Element? _nearestFacility(
    List<_Element> facilities,
    double lat,
    double lon,
  ) {
    _Element? best;
    var bestDistance = _facilityRadiusMeters;
    for (final facility in facilities) {
      final distance = _distanceMeters(lat, lon, facility.lat, facility.lon);
      if (distance < bestDistance) {
        best = facility;
        bestDistance = distance;
      }
    }
    return best;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);
}
