import 'package:flutter/material.dart';

class OnboardingLocationStep extends StatelessWidget {
  final double radiusKm;
  final ValueChanged<double> onRadiusChanged;

  const OnboardingLocationStep({
    super.key,
    required this.radiusKm,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicación', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text('Encuentra partners cerca de ti.', style: t.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('Madrid, España', style: t.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Radio: ${radiusKm.round()} km', style: t.labelMedium),
                  Slider(
                    value: radiusKm,
                    min: 1,
                    max: 50,
                    divisions: 49,
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
