import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../location/location_result.dart';
import '../../../theme/app_theme.dart';

/// Elegir un punto exacto moviendo el mapa bajo un pin fijo.
///
/// Sustituye a escribir el nombre de un municipio para quedar: para correr
/// (y para tenis fuera de un club) lo que importa es "en esta esquina del
/// parque", no "Malaga" — un buscador de sitios no puede expresar eso.
///
/// El pin va clavado en el centro de la pantalla y lo que se mueve es el
/// mapa: es el patron que usan Uber/Glovo y evita el lio de arrastrar un
/// marcador con el dedo justo encima, tapandolo.
class MapPointPicker extends StatefulWidget {
  /// Donde abrir el mapa. Normalmente la ubicacion del perfil, para no
  /// empezar en mitad del oceano.
  final LatLng initialCenter;
  final String title;

  const MapPointPicker({
    super.key,
    required this.initialCenter,
    this.title = 'Elige el punto exacto',
  });

  @override
  State<MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends State<MapPointPicker> {
  final _controller = MapController();
  late LatLng _center = widget.initialCenter;

  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final label = _labelCtrl.text.trim();
    Navigator.of(context).pop(
      LocationResult(
        displayName: label.isEmpty ? 'Punto de encuentro' : label,
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: 15,
                    // El punto elegido es siempre el centro de la camara,
                    // asi que basta con escuchar el movimiento del mapa.
                    onPositionChanged: (camera, _) {
                      setState(() => _center = camera.center);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.matchpoint.app',
                    ),
                  ],
                ),
                // Pin fijo, ligeramente elevado para que la punta caiga
                // justo en el centro geometrico del mapa.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: context.colors.primary,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black38),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _labelCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _confirm(),
                    decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                      hintText: 'Ej: entrada del parque, junto a la fuente',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Usar este punto'),
                    ),
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
