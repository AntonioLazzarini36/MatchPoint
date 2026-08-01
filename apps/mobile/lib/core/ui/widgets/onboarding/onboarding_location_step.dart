import 'package:flutter/material.dart';

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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicacion', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Escribe donde estas — no usamos tu ubicacion del dispositivo, '
            'la eliges tu y puedes cambiarla cuando quieras.',
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
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location?.displayName ?? 'Elegir ubicacion',
                            style: t.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: scheme.outline),
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
