import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/pace_format.dart';
import 'package:match_point/features/discovery/models/skill_level.dart';
import 'package:match_point/features/discovery/models/sport.dart';

/// Última página del wizard, antes de mandar nada al backend — pedido
/// del usuario (2026-08-03): quiere ver cómo va a quedar el perfil
/// (foto, nombre, deportes+nivel, bio, credenciales) y confirmar antes
/// de que se cree de verdad, en vez de que "Comenzar" en el paso de
/// fotos lo mande todo directo. Construida con los mismos bloques
/// visuales que `discovery_preview_sheet.dart` (lo que ve otra persona
/// en Discovery), pero con `Image.memory` en vez de `Image.network`
/// porque las fotos acá todavía son bytes locales — no se suben hasta
/// que se confirma esta página.
class OnboardingPreviewStep extends StatelessWidget {
  final List<Uint8List> photos;
  final String displayName;
  final int? age;
  final String? city;
  final String? bio;
  final List<Sport> sports;
  final Map<Sport, SkillLevel> skillLevels;
  final int? yearsPlaying;
  final String? club;
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;
  final List<String> achievements;

  const OnboardingPreviewStep({
    super.key,
    required this.photos,
    required this.displayName,
    required this.age,
    required this.city,
    required this.bio,
    required this.sports,
    required this.skillLevels,
    required this.yearsPlaying,
    required this.club,
    required this.avgPaceMinPerKm,
    required this.avgDistanceKm,
    required this.achievements,
  });

  bool get _hasCredentials =>
      yearsPlaying != null ||
      (club ?? '').isNotEmpty ||
      avgPaceMinPerKm != null ||
      avgDistanceKm != null ||
      achievements.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Así te van a ver', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Una última mirada antes de crear tu perfil de verdad.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: photos.isNotEmpty
                  ? Image.memory(photos.first, fit: BoxFit.cover)
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 64,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          if (photos.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              '+${photos.length - 1} foto(s) más',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            age == null ? displayName : '$displayName, $age',
            style: t.headlineSmall,
          ),
          if ((city ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                city!,
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          if (sports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sport in sports)
                    Chip(
                      label: Text(
                        skillLevels[sport] == null
                            ? sport.label
                            : '${sport.label} · ${skillLevels[sport]!.label}',
                      ),
                    ),
                ],
              ),
            ),
          if ((bio ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(bio!, style: t.bodyLarge),
            ),
          if (_hasCredentials)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _CredentialsPreview(
                yearsPlaying: yearsPlaying,
                club: club,
                avgPaceMinPerKm: avgPaceMinPerKm,
                avgDistanceKm: avgDistanceKm,
                achievements: achievements,
              ),
            ),
        ],
      ),
    );
  }
}

class _CredentialsPreview extends StatelessWidget {
  final int? yearsPlaying;
  final String? club;
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;
  final List<String> achievements;

  const _CredentialsPreview({
    required this.yearsPlaying,
    required this.club,
    required this.avgPaceMinPerKm,
    required this.avgDistanceKm,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experiencia',
          style: context.textStyles.titleSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (yearsPlaying != null)
          _infoRow(context, Icons.timeline, '$yearsPlaying años jugando'),
        if ((club ?? '').isNotEmpty)
          _infoRow(context, Icons.groups_outlined, club!),
        if (avgPaceMinPerKm != null)
          _infoRow(
            context,
            Icons.speed,
            'Ritmo medio: ${formatPaceMinPerKm(avgPaceMinPerKm)} min/km',
          ),
        if (avgDistanceKm != null)
          _infoRow(
            context,
            Icons.route,
            'Distancia media: $avgDistanceKm km',
          ),
        for (final achievement in achievements)
          _infoRow(context, Icons.emoji_events_outlined, achievement),
      ],
    );
  }

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
}
