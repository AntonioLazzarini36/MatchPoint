import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:match_point/app/routes.dart';

// ✅ Ajusta este import al archivo donde tengas AppSpacing + extensions context.colors/textStyles
// Ejemplo típico en tu proyecto:
import 'package:match_point/core/theme/app_theme.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // UI-only state (por ahora no persistimos nada)
  final Set<String> _selectedSports = {'Tenis', 'Correr'};
  String _goal = 'Jugar por nivel';
  double _radiusKm = 15;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNextOrFinish() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.shell);
    }
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;

    return Scaffold(
      appBar: AppBar(
        leading: _currentPage > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.shell),
            child: const Text('Saltar'),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildStep1(text, colors),
          _buildStep2(text, colors),
          _buildStep3(text, colors),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: AppSpacing.paddingLg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Indicators
            Row(
              children: List.generate(3, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.primary
                        : colors.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            ElevatedButton(
              onPressed: _goNextOrFinish,
              child: Text(_currentPage == 2 ? 'Comenzar' : 'Siguiente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(TextTheme text, ColorScheme colors) {
    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Elige tus deportes', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Selecciona los deportes que te interesan para encontrar tu partner ideal.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSportChip('Tenis', Icons.sports_tennis),
              _buildSportChip('Correr', Icons.directions_run),
              _buildSportChip('Pádel', Icons.sports_tennis),
              _buildSportChip('Yoga', Icons.self_improvement),
              _buildSportChip('Gym', Icons.fitness_center),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(TextTheme text, ColorScheme colors) {
    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cuál es tu objetivo?', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          _buildOptionCard(
            title: 'Jugar por nivel',
            subtitle: 'Busco mejorar y competir',
            icon: Icons.trending_up,
            selected: _goal == 'Jugar por nivel',
            onTap: () => setState(() => _goal = 'Jugar por nivel'),
          ),
          _buildOptionCard(
            title: 'Conocer gente',
            subtitle: 'Busco socializar y divertirme',
            icon: Icons.people,
            selected: _goal == 'Conocer gente',
            onTap: () => setState(() => _goal = 'Conocer gente'),
          ),
          _buildOptionCard(
            title: 'Ambos',
            subtitle: 'Un poco de todo',
            icon: Icons.favorite,
            selected: _goal == 'Ambos',
            onTap: () => setState(() => _goal = 'Ambos'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(TextTheme text, ColorScheme colors) {
    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicación', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text('Encuentra partners cerca de ti.', style: text.bodyLarge),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: colors.primary),
                      const SizedBox(width: 8),
                      Text('Madrid, España', style: text.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Radio: ${_radiusKm.round()} km',
                    style: text.labelMedium,
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    onChanged: (val) => setState(() => _radiusKm = val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportChip(String label, IconData icon) {
    final selected = _selectedSports.contains(label);

    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _selectedSports.add(label);
          } else {
            _selectedSports.remove(label);
          }
        });
      },
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: selected ? scheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
