import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../../../features/discovery/models/skill_level.dart';
import '../../../features/discovery/models/sport.dart';
import 'profile_header_data.dart';

class ProfileView extends StatelessWidget {
  final ProfileHeaderData data;

  final String sportsTitle;
  final String bioTitle;

  final bool showStats;
  final bool showBottomButton;

  final VoidCallback? onSettings;
  final VoidCallback? onEdit;
  final VoidCallback? onBottomButton;
  final String bottomButtonText;

  /// Acciones adicionales al final del AppBar (p.ej. el menú de
  /// bloquear/reportar en el perfil público de otro usuario) — se
  /// renderizan después del icono de settings, si lo hay.
  final List<Widget>? extraActions;

  const ProfileView({
    super.key,
    required this.data,
    this.sportsTitle = 'Deportes',
    this.bioTitle = 'Sobre',
    this.showStats = true,
    this.showBottomButton = false,
    this.bottomButtonText = 'Ver perfil',
    this.onBottomButton,
    this.onSettings,
    this.onEdit,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: data.photos.isEmpty
                ? _emptyHeader(context)
                : _PhotoCarousel(photos: data.photos),
          ),
          actions: [
            if (onSettings != null)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: onSettings,
              ),
            ...?extraActions,
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Name/Age + City + Edit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            style: context.textStyles.headlineMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.subtitle,
                            style: context.textStyles.bodyLarge?.copyWith(
                              color: context.colors.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              context.colors.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Sports
                Text(sportsTitle, style: context.textStyles.titleMedium),
                const SizedBox(height: 12),
                _sportsWrap(context, data.sports),

                const SizedBox(height: 24),

                // Bio
                Text(bioTitle, style: context.textStyles.titleMedium),
                const SizedBox(height: 8),
                Text(
                  (data.bio == null || data.bio!.trim().isEmpty)
                      ? 'Aun no hay bio.'
                      : data.bio!,
                  style: context.textStyles.bodyMedium,
                ),

                if (_hasCredentials) ...[
                  const SizedBox(height: 24),
                  Text('Experiencia', style: context.textStyles.titleMedium),
                  const SizedBox(height: 8),
                  if (data.yearsPlaying != null)
                    _infoRow(
                      context,
                      Icons.timeline,
                      '${data.yearsPlaying} años jugando',
                    ),
                  if ((data.club ?? '').isNotEmpty)
                    _infoRow(context, Icons.groups_outlined, data.club!),
                  if (data.avgPaceMinPerKm != null)
                    _infoRow(
                      context,
                      Icons.speed,
                      'Ritmo medio: ${data.avgPaceMinPerKm} min/km',
                    ),
                  if (data.avgDistanceKm != null)
                    _infoRow(
                      context,
                      Icons.route,
                      'Distancia media: ${data.avgDistanceKm} km',
                    ),
                  for (final achievement in data.achievements)
                    _infoRow(
                      context,
                      Icons.emoji_events_outlined,
                      achievement,
                    ),
                ],

                const SizedBox(height: 24),

                // Stats (optional)
                if (showStats) ...[
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(context, 'Matches', '—')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(context, 'Likes', '—')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(context, 'Karma', '—')),
                    ],
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const SizedBox(height: 8),
                ],

                // Bottom button (optional)
                if (showBottomButton) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onBottomButton,
                      child: Text(bottomButtonText),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyHeader(BuildContext context) {
    return Container(
      color: context.colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person,
          size: 72,
          color: context.colors.outline,
        ),
      ),
    );
  }

  Widget _sportsWrap(BuildContext context, List<Sport> sports) {
    if (sports.isEmpty) {
      return Text(
        'Aun no hay deportes.',
        style: context.textStyles.bodyMedium
            ?.copyWith(color: context.colors.outline),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sports.map((s) => _sportChip(context, s)).toList(),
    );
  }

  Widget _sportChip(BuildContext context, Sport sport) {
    final icon = _sportIcon(sport);
    final level = data.skillLevels[sport];
    final label = level == null
        ? _sportLabel(sport)
        : '${_sportLabel(sport)} · ${level.label}';

    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: context.colors.surfaceContainerHighest,
    );
  }

  bool get _hasCredentials =>
      data.yearsPlaying != null ||
      (data.club ?? '').isNotEmpty ||
      data.avgPaceMinPerKm != null ||
      data.avgDistanceKm != null ||
      data.achievements.isNotEmpty;

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium)),
        ],
      ),
    );
  }

  IconData _sportIcon(Sport s) {
    switch (s) {
      case Sport.tennis:
        return Icons.sports_tennis;
      case Sport.running:
        return Icons.directions_run;
    }
  }

  String _sportLabel(Sport s) {
    switch (s) {
      case Sport.tennis:
        return 'Tenis';
      case Sport.running:
        return 'Running';
    }
  }

  Widget _buildStatCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outline.withValues(alpha:0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: context.textStyles.headlineMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrusel horizontal con puntos indicadores para las fotos del perfil
/// (a diferencia de las cards de discovery, que de momento solo muestran
/// la primera foto — eso se rediseñará aparte).
class _PhotoCarousel extends StatefulWidget {
  final List<String> photos;

  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) =>
              Image.network(widget.photos[i], fit: BoxFit.cover),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}