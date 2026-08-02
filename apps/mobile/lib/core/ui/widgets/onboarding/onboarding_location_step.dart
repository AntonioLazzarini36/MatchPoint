import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../location/location_result.dart';
import '../../location/location_search_screen.dart';

class OnboardingLocationStep extends StatelessWidget {
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

  Future<void> _pickLocation(BuildContext context) async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (result != null) onLocationChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final loc = location;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicacion', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Escribe donde estas — no usamos tu ubicacion del dispositivo, '
            'la eliges tu y puedes cambiarla cuando quieras. La usamos '
            'para mostrarte gente dentro del radio que elijas, nunca la '
            'compartimos exacta con nadie.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _pickLocation(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc?.displayName ?? 'Elegir ubicacion',
                                style: t.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.chevron_right, color: scheme.outline),
                          ],
                        ),
                        if (loc != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 120,
                              child: IgnorePointer(
                                // Solo decorativo — tocar en cualquier
                                // parte de la tarjeta abre el buscador
                                // (el InkWell de arriba), el mapa no
                                // necesita capturar sus propios gestos.
                                //
                                // `key` a propósito ligada a las
                                // coordenadas: `MapOptions.initialCenter`
                                // solo se aplica al montar el widget la
                                // primera vez, no en cada rebuild — sin
                                // esta key, elegir una ubicación nueva
                                // dejaba la cámara del mapa en el sitio
                                // viejo (el pin se movía a las coordenadas
                                // correctas pero quedaba fuera de la
                                // vista). La key fuerza un remount
                                // completo del mapa cada vez que cambian
                                // las coordenadas, así vuelve a centrar.
                                child: FlutterMap(
                                  key: ValueKey('${loc.latitude}_${loc.longitude}'),
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      loc.latitude,
                                      loc.longitude,
                                    ),
                                    initialZoom: 12,
                                    interactionOptions: const InteractionOptions(
                                      flags: InteractiveFlag.none,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.matchpoint.app',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            loc.latitude,
                                            loc.longitude,
                                          ),
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
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Radio: ${radiusKm.round()} km', style: t.labelMedium),
                  Slider(
                    value: radiusKm,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    onChanged: onRadiusChanged,
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
