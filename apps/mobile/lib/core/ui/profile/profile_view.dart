import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../../utils/landscape_crop.dart';
import '../../utils/pace_format.dart';
import '../../../features/discovery/models/skill_level.dart';
import '../../../features/discovery/models/sport.dart';
import '../../../features/onboarding/models/availability.dart';
import '../../../features/onboarding/models/intention.dart';
import 'profile_header_data.dart';
import 'network_photo.dart';

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
    // La cabecera ocupa exactamente un 16:9 del ancho de pantalla, que es
    // la proporcion en la que se guardan las fotos (ver landscape_crop
    // .dart): con un alto fijo, el recorte de la cabecera no coincidia con
    // el que el usuario habia aprobado al subirla.
    final headerHeight = MediaQuery.sizeOf(context).width / kPhotoAspectRatio;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: headerHeight,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: data.photos.isEmpty
                ? _emptyHeader(context)
                : NetworkPhoto(url: data.photos.first, iconSize: 56),
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

                if (data.availability.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Cuándo juega', style: context.textStyles.titleMedium),
                  const SizedBox(height: 8),
                  _infoRow(
                    context,
                    Icons.schedule,
                    availabilitySummary(data.availability),
                  ),
                ],

                if (data.intention != null) ...[
                  const SizedBox(height: 24),
                  Text('A que viene', style: context.textStyles.titleMedium),
                  const SizedBox(height: 8),
                  _infoRow(
                    context,
                    data.intention!.icon,
                    '${data.intention!.label} — ${data.intention!.description}',
                  ),
                ],

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
                      'Ritmo medio: ${formatPaceMinPerKm(data.avgPaceMinPerKm)} min/km',
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

                if (data.photos.length > 1) ...[
                  const SizedBox(height: 24),
                  Text('Fotos', style: context.textStyles.titleMedium),
                  const SizedBox(height: 12),
                  // En vertical y a lo ancho, no en un carrusel lateral:
                  // el carrusel escondia todas las fotos menos la primera
                  // detras de un gesto que nada indicaba, asi que en la
                  // practica el resto del perfil no se veia nunca.
                  for (final photo in data.photos.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: AspectRatio(
                          aspectRatio: kPhotoAspectRatio,
                          child: NetworkPhoto(url: photo),
                        ),
                      ),
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
