import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../location/geocoding_service.dart';
import '../../../location/location_result.dart';
import '../../../theme/app_theme.dart';
import 'name_place_dialog.dart';
import '../../../../features/courts/models/tennis_club.dart';
import '../../../../features/courts/services/overpass_service.dart';

/// Lista de pistas y clubes de tenis reales cerca de un punto, para elegir
/// dónde jugar al proponer una quedada.
///
/// Existe porque el buscador por nombre es un geocodificador de sitios
/// (Nominatim) y en la práctica sólo devuelve municipios y calles: buscar
/// "club de tenis" allí no encuentra pistas. Los datos de pistas sí están
/// en OpenStreetMap, pero hay que pedirlos por etiqueta, que es lo que
/// hace `OverpassService` para el mapa de clubes — aquí se reutiliza tal
/// cual, en formato lista y devolviendo un [LocationResult] para que
/// encaje con el resto del flujo de propuestas.
///
/// Buena parte de las pistas de OSM **no tienen nombre**. Para esas, en
/// vez de mandar "Club de tenis" (que ni es necesariamente un club ni
/// distingue un sitio de otro), se pide confirmación con un nombre
/// editable, propuesto a partir de la calle real del sitio.
class TennisClubPicker extends StatefulWidget {
  final LatLng center;

  const TennisClubPicker({super.key, required this.center});

  @override
  State<TennisClubPicker> createState() => _TennisClubPickerState();
}

class _TennisClubPickerState extends State<TennisClubPicker> {
  final _service = OverpassService();
  final _geocoding = GeocodingService();
  final _searchCtrl = TextEditingController();

  List<TennisClub> _clubs = const [];
  bool _loading = true;
  bool _failed = false;

  /// Direcciones resueltas por geocodificacion inversa para las pistas que
  /// OSM no tiene nombradas, por id de grupo. Se rellenan poco a poco (ver
  /// [_labelNearbyUnnamed]) y se pintan en cuanto llegan.
  final Map<String, String> _resolved = {};

  /// Cambia en cada carga para que un etiquetado en curso se pare solo si
  /// se recarga o se amplia el radio.
  int _loadToken = 0;

  /// Se empieza con 10 km y se puede ampliar: en un pueblo puede no haber
  /// nada a 10 km, y pedir siempre 30 km hace la consulta mucho más lenta
  /// para quien vive en una ciudad con pistas al lado.
  int _radiusMeters = 10000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _failed = false;
      _resolved.clear();
    });
    try {
      final clubs = await _service.nearbyClubs(
        latitude: widget.center.latitude,
        longitude: widget.center.longitude,
        radiusMeters: _radiusMeters,
      );
      // Los que tienen nombre real primero (son los clubes que la
      // otra persona va a reconocer al recibir la propuesta) y,
      // dentro de cada grupo, por cercanía. Ordenar sólo por
      // distancia dejaba arriba pistas sueltas de urbanización y
      // enterraba el club de 8 pistas de al lado.
      clubs.sort((a, b) {
        if (a.hasRealName != b.hasRealName) return a.hasRealName ? -1 : 1;
        return _distanceKm(a).compareTo(_distanceKm(b));
      });
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _loading = false;
      });
      _labelNearbyUnnamed(token);
    } catch (e) {
      // El detalle técnico ("TimeoutException after 0:00:20...") no le
      // dice nada a nadie y ocupa media pantalla; queda en la consola,
      // que es donde sirve para algo.
      debugPrint('Overpass falló: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// Le pone direccion real a las pistas sin nombre **mas cercanas**, de
  /// una en una y espaciadas en el tiempo.
  ///
  /// Hace falta porque en la practica casi ninguna pista de OSM tiene
  /// etiqueta `name` (3 de 106 cerca de Benalmadena, comprobado), asi que
  /// sin esto la lista entera dice "Pistas de tenis" y no hay forma de
  /// distinguir una de otra.
  ///
  /// Solo las [_maxToLabel] mas cercanas, y con [_labelInterval] entre
  /// peticiones: la politica de uso de Nominatim pide como maximo ~1
  /// peticion por segundo, y de todas formas nadie queda para jugar en la
  /// pista numero 40 por distancia. Las demas se resuelven igualmente al
  /// elegirlas, con una sola peticion.
  static const _maxToLabel = 12;
  static const _labelInterval = Duration(milliseconds: 1100);

  Future<void> _labelNearbyUnnamed(int token) async {
    final pending = _clubs
        .where((c) => !c.hasRealName && c.street == null)
        .take(_maxToLabel)
        .toList();

    for (final club in pending) {
      if (!mounted || token != _loadToken) return;
      final address = await _geocoding.reverse(club.latitude, club.longitude);
      if (!mounted || token != _loadToken) return;
      if (address != null) {
        setState(() => _resolved[club.id] = address);
      }
      await Future<void>.delayed(_labelInterval);
    }
  }

  /// Lo que se enseña y lo que se propone como nombre: la direccion ya
  /// resuelta si la hay, si no la calle de OSM, si no el generico.
  String _label(TennisClub club) {
    if (club.hasRealName) return club.name;
    final address = _resolved[club.id] ?? club.street;
    return address == null ? 'Pistas de tenis' : 'Pistas de tenis · $address';
  }

  void _widenSearch() {
    setState(() => _radiusMeters = 30000);
    _load();
  }

  double _distanceKm(TennisClub club) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(club.latitude - widget.center.latitude);
    final dLon = rad(club.longitude - widget.center.longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(widget.center.latitude)) *
            math.cos(rad(club.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  List<TennisClub> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _clubs;
    return _clubs
        .where((c) => _label(c).toLowerCase().contains(query))
        .toList();
  }

  /// Con nombre real de OSM se devuelve tal cual. Sin él, se pide una
  /// confirmación con el nombre editable: quien recibe la propuesta tiene
  /// que poder leer dónde queda, y "Pistas de tenis" repetido diez veces
  /// no vale para eso.
  Future<void> _select(TennisClub club) async {
    if (club.hasRealName) {
      Navigator.of(context).pop(
        LocationResult(
          displayName: club.name,
          latitude: club.latitude,
          longitude: club.longitude,
        ),
      );
      return;
    }

    // Puede que el etiquetado de fondo ya lo haya resuelto; si no (estaba
    // mas abajo en la lista), se pide ahora, que es una sola peticion.
    var suggestion = _resolved[club.id] ?? club.street;
    if (suggestion == null) {
      suggestion = await _geocoding.reverse(club.latitude, club.longitude);
      if (!mounted) return;
      if (suggestion != null) {
        setState(() => _resolved[club.id] = suggestion!);
      }
    }
    if (!mounted) return;

    final name = await askPlaceName(
      context,
      suggestion: suggestion == null
          ? 'Pistas de tenis'
          : 'Pistas de tenis · $suggestion',
      courtCount: club.courtCount,
    );
    if (name == null || !mounted) return;

    Navigator.of(context).pop(
      LocationResult(
        displayName: name,
        latitude: club.latitude,
        longitude: club.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dónde jugáis')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Filtrar por nombre...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_failed) {
      return _message(
        context,
        icon: Icons.cloud_off,
        title: 'No se pudo cargar el listado',
        // Overpass es el servicio público y gratuito de consultas de
        // OpenStreetMap: lo comparte todo el mundo y se satura a ratos.
        // Reintentar suele bastar, y si no, el mapa no depende de él.
        detail: 'El servicio de mapas está saturado ahora mismo. Prueba otra '
            'vez, o marca el sitio a mano en el mapa.',
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      final filtered = _searchCtrl.text.trim().isNotEmpty;
      return _message(
        context,
        icon: Icons.sports_tennis,
        title: filtered
            ? 'Ningún sitio con ese nombre'
            : 'No hay pistas registradas a '
                  '${(_radiusMeters / 1000).round()} km',
        detail: filtered
            ? 'Prueba con otra parte del nombre.'
            : 'Los datos vienen de OpenStreetMap, así que puede faltar '
                  'alguna pista. Puedes ampliar la búsqueda o marcar el '
                  'sitio a mano en el mapa.',
        actionLabel: (!filtered && _radiusMeters < 30000)
            ? 'Buscar hasta 30 km'
            : null,
        onAction: _widenSearch,
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _clubTile(context, visible[i]),
    );
  }

  Widget _clubTile(BuildContext context, TennisClub club) {
    final distance = _distanceKm(club);
    final courts =
        '${club.courtCount} ${club.courtCount == 1 ? 'pista' : 'pistas'}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: club.hasRealName
            ? context.colors.primaryContainer
            : context.colors.surfaceContainerHighest,
        child: Icon(
          Icons.sports_tennis,
          color: club.hasRealName
              ? context.colors.onPrimaryContainer
              : context.colors.onSurfaceVariant,
        ),
      ),
      title: Text(_label(club)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$courts · ${distance.toStringAsFixed(1)} km'),
          // Decirlo antes de tocar, no después: así se entiende por qué
          // media lista se llama igual y por qué al elegirla te pide un
          // nombre.
          if (!club.hasRealName)
            Text(
              'Sin nombre en OpenStreetMap · lo confirmas tú',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      isThreeLine: !club.hasRealName,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _select(club),
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
