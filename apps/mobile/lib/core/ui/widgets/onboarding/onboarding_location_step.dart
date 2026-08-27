import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../network/api.dart';
import '../../../../features/onboarding/services/density_service.dart';
import '../../../location/geocoding_service.dart';
import '../../../location/location_result.dart';
import '../../../network/connection_error.dart';
import '../../location/location_search_screen.dart';

/// Primer paso del registro, y a propósito.
///
/// Antes era el cuarto: se preguntaba el nombre, el nivel, las credenciales y
/// las preferencias, y sólo entonces dónde estabas. Eso deja la única
/// pregunta que puede responder "¿hay alguien aquí?" para después de que la
/// persona ya ha invertido cinco pantallas — y si la respuesta es "no", se
/// enteraba al final, con el perfil hecho y Descubrir vacío.
///
/// Ahora va primera y **contesta esa pregunta mientras eliges**: en cuanto
/// hay un sitio marcado, pregunta al servidor cuánta gente juega cerca y lo
/// dice.
///
/// **Se entra por el código postal**, no por un buscador de texto libre. El
/// buscador seguía abriendo una pantalla aparte que devolvía barrios, calles
/// y urbanizaciones mezclados, y había que decidir cuál de ocho resultados
/// parecidos era el tuyo — con un mapa de 120 px que no daba para reconocer
/// nada. Cinco dígitos que la gente ya se sabe dan el municipio directamente.
/// Quien no lo sepa (o no esté en España) tiene debajo el buscador por
/// nombre, que es el de siempre.
class OnboardingLocationStep extends StatefulWidget {
  final LocationResult? location;
  final ValueChanged<LocationResult> onLocationChanged;
  final double radiusKm;
  final ValueChanged<double> onRadiusChanged;

  const OnboardingLocationStep({
    super.key,
    required this.location,
    required this.onLocationChanged,
    required this.radiusKm,
    required this.onRadiusChanged,
  });

  @override
  State<OnboardingLocationStep> createState() => _OnboardingLocationStepState();
}

class _OnboardingLocationStepState extends State<OnboardingLocationStep> {
  final _density = DensityService(Api.client);
  final _geocoding = GeocodingService();
  final _postalCtrl = TextEditingController();

  /// Un solo temporizador para las dos cosas que se disparan escribiendo o
  /// arrastrando. **Esto es lo que estaba roto**: el contador se pedía desde
  /// `didUpdateWidget`, así que arrastrar el slider lanzaba una petición por
  /// cada píxel del recorrido. En diez ticks se agotaba el límite por IP y el
  /// resto contestaba 429, o sea que el número desaparecía y no volvía en un
  /// minuto — se veía como "sólo funciona la primera vez". Ahora se espera a
  /// que el gesto pare, y sólo entonces se pregunta una vez.
  Timer? _debounce;

  int? _count;
  bool _countLoading = false;

  /// Para qué (sitio, radio) es el número que hay en pantalla: así una
  /// respuesta que llega tarde no pisa a una consulta más nueva.
  String? _countKey;

  bool _postalLoading = false;
  String? _postalError;

  static const _debounceDelay = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _scheduleCount();
  }

  @override
  void didUpdateWidget(OnboardingLocationStep old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location || old.radiusKm != widget.radiusKm) {
      _scheduleCount();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _postalCtrl.dispose();
    super.dispose();
  }

  String _keyFor(LocationResult loc, double radius) =>
      '${loc.latitude},${loc.longitude},${radius.round()}';

  void _scheduleCount() {
    _debounce?.cancel();
    final loc = widget.location;
    if (loc == null) {
      setState(() {
        _count = null;
        _countKey = null;
        _countLoading = false;
      });
      return;
    }
    if (_keyFor(loc, widget.radiusKm) == _countKey) return;

    // Se marca "cargando" ya, no cuando salga la petición: entre que sueltas
    // el dedo y pasa el debounce, el número de pantalla es el del radio
    // anterior y decirlo como bueno sería mentir durante medio segundo.
    setState(() => _countLoading = true);
    _debounce = Timer(_debounceDelay, _fetchCount);
  }

  Future<void> _fetchCount() async {
    final loc = widget.location;
    if (loc == null) return;
    final key = _keyFor(loc, widget.radiusKm);

    final result = await _density.countNear(
      lat: loc.latitude,
      lng: loc.longitude,
      radiusKm: widget.radiusKm.round(),
    );
    if (!mounted) return;

    // ¿Sigue siendo la consulta vigente? Si no, se tira sin tocar nada.
    final current = widget.location;
    if (current == null || _keyFor(current, widget.radiusKm) != key) return;

    setState(() {
      _countLoading = false;
      // Un fallo (sin red, o el servidor de mal humor) deja el número como
      // estaba en vez de borrarlo: `countNear` devuelve null tanto para "no
      // pude preguntar" como para nada, y pintar eso como "no hay nadie"
      // sería la peor forma posible de equivocarse aquí.
      if (result != null) {
        _count = result;
        _countKey = key;
      }
    });
  }

  Future<void> _lookupPostalCode(String code) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _postalLoading = true;
      _postalError = null;
    });

    try {
      final results = await _geocoding.searchPostalCode(code);
      if (!mounted) return;
      setState(() => _postalLoading = false);

      if (results.isEmpty) {
        setState(
          () => _postalError =
              'No encontramos ese código postal. Revísalo o busca tu '
              'ciudad por el nombre.',
        );
        return;
      }
      // Más de un resultado es raro pero pasa (códigos que cubren varios
      // núcleos): se pregunta en vez de elegir por su cuenta.
      if (results.length == 1) {
        widget.onLocationChanged(results.first);
        return;
      }
      final picked = await showModalBottomSheet<LocationResult>(
        context: context,
        builder: (_) => _PlaceChoiceSheet(options: results),
      );
      if (picked != null) widget.onLocationChanged(picked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postalLoading = false;
        _postalError = friendlyError(
          e,
          fallback: 'No se ha podido buscar el código postal.',
        );
      });
    }
  }

  Future<void> _searchByName() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (result != null) {
      setState(() => _postalError = null);
      widget.onLocationChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final loc = widget.location;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Dónde juegas?', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Escribe tu código postal y te mostraremos gente cerca de ti.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _postalCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código postal',
                    hintText: '29639',
                    prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                  ),
                  // Se busca solo al llegar al quinto dígito: un código postal
                  // español siempre los tiene, así que pedir además un toque
                  // en un botón es un paso que no decide nada.
                  onChanged: (value) {
                    if (value.length == 5) _lookupPostalCode(value);
                  },
                  onSubmitted: _lookupPostalCode,
                ),
              ),
              if (_postalLoading) ...[
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ],
          ),

          if (_postalError != null) ...[
            const SizedBox(height: 8),
            Text(
              _postalError!,
              style: t.bodySmall?.copyWith(color: scheme.error),
            ),
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _searchByName,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('No lo sé — buscar por ciudad'),
            ),
          ),

          const SizedBox(height: 8),

          if (loc == null)
            _EmptyHint(scheme: scheme, style: t.bodySmall)
          else ...[
            _ChosenPlace(
              location: loc,
              radiusKm: widget.radiusKm,
              onChange: _searchByName,
            ),
            const SizedBox(height: 16),
            Text(
              'Hasta ${widget.radiusKm.round()} km de distancia',
              style: t.labelMedium,
            ),
            Slider(
              value: widget.radiusKm,
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: widget.onRadiusChanged,
            ),
            const SizedBox(height: 8),
            _DensityNote(count: _count, loading: _countLoading),
          ],
        ],
      ),
    );
  }
}

/// Lo que se ve antes de elegir nada: por qué se pide esto.
class _EmptyHint extends StatelessWidget {
  final ColorScheme scheme;
  final TextStyle? style;

  const _EmptyHint({required this.scheme, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sólo usamos tu zona para calcular distancias. Nadie ve dónde '
              'vives: en los perfiles sólo aparece a cuántos kilómetros estás.',
              style: style?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// El sitio elegido, con el municipio en grande y un mapa que se ve.
///
/// El mapa de antes eran 120 px sin escala ni referencia: se veían cuatro
/// calles y un pin, que no basta para reconocer si el sitio es el tuyo. Ahora
/// ocupa 180, y encima lleva **dibujado el círculo del radio**, que es lo que
/// convierte "25 km" en algo que se puede juzgar de un vistazo: se ve hasta
/// dónde llega y qué pueblos entran.
class _ChosenPlace extends StatelessWidget {
  final LocationResult location;
  final double radiusKm;
  final VoidCallback onChange;

  const _ChosenPlace({
    required this.location,
    required this.radiusKm,
    required this.onChange,
  });

  /// Zoom que deja el círculo del radio ocupando más o menos el ancho del
  /// mapa. Sale de la resolución de las teselas de OSM: a zoom `z` el mundo
  /// mide `256 * 2^z` px, así que el zoom que encaja un diámetro dado es un
  /// logaritmo — calcularlo evita que a 5 km se vea el país entero y a 100 km
  /// no quepa el círculo.
  double get _zoom {
    final diameterKm = radiusKm * 2;
    final worldKm = 40075 * math.cos(location.latitude * math.pi / 180);
    // 320 px de ancho útil aproximado para la tarjeta.
    final z = math.log(worldKm * 320 / (256 * diameterKm)) / math.ln2;
    return z.clamp(3.0, 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final centre = LatLng(location.latitude, location.longitude);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.location_on, color: scheme.primary),
            title: Text(
              location.displayName,
              style: t.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: onChange,
              child: const Text('Cambiar'),
            ),
          ),
          SizedBox(
            height: 180,
            child: IgnorePointer(
              // `key` atada a coordenadas y radio: `MapOptions.initialCenter`
              // y `initialZoom` sólo se aplican al montar el widget, no en
              // cada rebuild. Sin esto, cambiar de sitio movía el pin pero
              // dejaba la cámara donde estaba, y mover el radio no reajustaba
              // el zoom — el círculo se salía de la tarjeta.
              child: FlutterMap(
                key: ValueKey(
                  '${location.latitude}_${location.longitude}_${radiusKm.round()}',
                ),
                options: MapOptions(
                  initialCenter: centre,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.matchpoint.app',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: centre,
                        radius: radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderColor: scheme.primary.withValues(alpha: 0.7),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: centre,
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.location_on,
                          color: scheme.primary,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuando un código postal cae en varios núcleos.
class _PlaceChoiceSheet extends StatelessWidget {
  final List<LocationResult> options;

  const _PlaceChoiceSheet({required this.options});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '¿Cuál de estos?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final option in options)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(option.displayName),
              onTap: () => Navigator.of(context).pop(option),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Lo que hay alrededor, dicho antes de pedir nada más.
class _DensityNote extends StatelessWidget {
  final int? count;
  final bool loading;

  const _DensityNote({required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (loading && count == null) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Mirando quién juega por ahí…', style: t.bodyMedium),
        ],
      );
    }

    // No se pudo consultar nunca: mejor no decir nada que decir un número
    // falso.
    if (count == null) return const SizedBox.shrink();

    final none = count == 0;
    final (icon, title, body) = none
        ? (
            Icons.flag_outlined,
            'Todavía no hay nadie por aquí',
            'Serías de los primeros. Te avisamos en cuanto alguien se '
                'apunte cerca — y mientras tanto puedes ampliar el radio '
                'para ver más lejos.',
          )
        : (
            Icons.groups_outlined,
            count == 1
                ? 'Hay 1 persona jugando por aquí'
                : 'Hay $count personas jugando por aquí',
            'Podrás verlas en cuanto termines de crear tu perfil.',
          );

    return AnimatedOpacity(
      // Mientras se recalcula, el número que hay en pantalla es el del radio
      // anterior: se atenúa en vez de desaparecer, así el bloque no salta de
      // sitio en cada movimiento del slider.
      opacity: loading ? 0.45 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: none ? scheme.surfaceContainerHighest : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: none ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleSmall?.copyWith(
                      color: none
                          ? scheme.onSurface
                          : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: t.bodySmall?.copyWith(
                      color: none
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
