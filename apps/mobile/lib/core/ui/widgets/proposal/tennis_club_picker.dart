import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../location/location_result.dart';
import '../../../theme/app_theme.dart';
import '../../../../features/courts/models/tennis_club.dart';
import '../../../../features/courts/services/overpass_service.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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
  final _searchCtrl = TextEditingController();

  List<TennisClub> _clubs = const [];
  bool _loading = true;
  bool _failed = false;

  /// Direcciones resueltas por geocodificacion inversa para las pistas que
  /// OSM no tiene nombradas, por id de grupo. Se rellenan poco a poco (ver
  /// [_labelNearbyUnnamed]) y se pintan en cuanto llegan.

  /// Cambia en cada carga para que un etiquetado en curso se pare solo si
  /// se recarga o se amplia el radio.

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
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final clubs = await _service.nearbyClubs(
        latitude: widget.center.latitude,
        longitude: widget.center.longitude,
        radiusMeters: _radiusMeters,
      );
      // **Sólo las que tienen nombre en OpenStreetMap.**
      //
      // El resto eran pistas sueltas que aparecían como "Pistas de tenis" a
      // secas, y no aportan nada: quien recibe la propuesta necesita saber a
      // dónde ir, y un sitio sin nombre no se lo dice. Había toda una
      // maquinaria para taparlo —geocodificación inversa de las 12 más
      // cercanas, de una en una cada 1,1 s por la política de Nominatim, y un
      // diálogo para que quien elegía le pusiera nombre a mano— que resolvía
      // a medias un problema que se arregla mejor no enseñándolas. De paso se
      // ahorran doce peticiones de red en cada carga.
      //
      // Quien quiera quedar en un sitio sin nombre tiene el botón de marcar
      // en el mapa, que es exactamente para eso.
      final named = clubs.where((c) => c.hasRealName).toList()
        ..sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));
      if (!mounted) return;
      setState(() {
        _clubs = named;
        _loading = false;
      });
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
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  /// Todos los de la lista tienen nombre de OSM (ver `_load`), así que
  /// elegir uno es devolverlo y ya. Antes, para los que no lo tenían, había
  /// que resolver una dirección por geocodificación inversa y abrir un
  /// diálogo pidiéndole a quien elegía que le pusiera nombre a mano.
  void _select(TennisClub club) {
    Navigator.of(context).pop(
      LocationResult(
        displayName: club.name,
        latitude: club.latitude,
        longitude: club.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.current.whereYouPlay)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: S.current.filterByName,
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
        title: S.current.couldNotLoadList,
        // Overpass es el servicio público y gratuito de consultas de
        // OpenStreetMap: lo comparte todo el mundo y se satura a ratos.
        // Reintentar suele bastar, y si no, el mapa no depende de él.
        detail:
            S.current.mapServiceBusy,
        actionLabel: S.current.retry,
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
            ? S.current.noPlaceWithThatName
            : 'No hay pistas registradas a '
                  '${(_radiusMeters / 1000).round()} km',
        detail: filtered
            ? S.current.tryAnotherPartOfName
            : S.current.osmDataMayBeMissing,
        actionLabel: (!filtered && _radiusMeters < 30000)
            ? S.current.searchUpToKm(30)
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
      title: Text(club.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$courts · ${distance.toStringAsFixed(1)} km'),
          // Decirlo antes de tocar, no después: así se entiende por qué
          // media lista se llama igual y por qué al elegirla te pide un
          // nombre.
          if (!club.hasRealName)
            Text(
              S.current.noNameInOsmYouConfirm,
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
