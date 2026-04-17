import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = data.mainPhoto;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: photoUrl == null
                ? _emptyHeader(context)
                : Image.network(photoUrl, fit: BoxFit.cover),
          ),
          actions: [
            if (onSettings != null)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: onSettings,
              ),
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
                      ? 'Aún no hay bio.'
                      : data.bio!,
                  style: context.textStyles.bodyMedium,
                ),

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
        'Aún no hay deportes.',
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
    final label = _sportLabel(sport);

    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: context.colors.surfaceContainerHighest,
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