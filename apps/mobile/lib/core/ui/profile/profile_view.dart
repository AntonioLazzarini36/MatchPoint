import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';

import '../../utils/landscape_crop.dart';
import '../../utils/pace_format.dart';
import '../../../features/discovery/models/level_verdict.dart';
import '../../../features/discovery/models/skill_level.dart';
import '../../../features/discovery/models/sport.dart';
import '../widgets/availability_picker.dart';
import '../../../features/onboarding/models/intention.dart';
import 'profile_header_data.dart';
import 'network_photo.dart';

class ProfileView extends StatelessWidget {
  final ProfileHeaderData data;

  final String sportsTitle;
  final String bioTitle;

  final bool showStats;

  /// Las cifras del perfil propio. `null` mientras se cargan o si no se han
  /// pedido: la fila entera desaparece en vez de enseñar ceros o guiones, que
  /// es lo que hacia antes y no informaba de nada.
  final ProfileStats? stats;
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
    this.stats,
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
          // Ajustes ya no va aqui: encima de la foto, un icono blanco sobre
          // una imagen clara desaparece, y era el unico acceso a media app
          // (ubicacion, horario, nivel, borrar cuenta). Ha bajado a la fila
          // del nombre, sobre fondo solido, junto al lapiz — ver abajo.
          actions: [...?extraActions],
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
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onEdit,
                        tooltip: 'Cambiar fotos',
                        icon: const Icon(Icons.edit_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              context.colors.surfaceContainerHighest,
                        ),
                      ),
                    ],
                    if (onSettings != null) ...[
                      const SizedBox(width: 8),
                      // Relleno en color, no gris como el lapiz: es la puerta
                      // a la mitad de la app (ubicacion, horario, nivel,
                      // cerrar sesion) y tiene que encontrarse sin buscarla.
                      IconButton(
                        onPressed: onSettings,
                        tooltip: 'Ajustes',
                        icon: const Icon(Icons.settings),
                        style: IconButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: context.colors.onPrimary,
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

                // Sin titulo encima: la rejilla ya trae escritos los dias
                // (L M X J V S D) y las franjas (Mañana/Tarde/Noche), asi que
                // "Cuándo suele tener libre" era repetir con palabras lo que
                // el dibujo dice mejor.
                if (data.availability.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AvailabilityView(
                    value: data.availability,
                    highlight: data.sharedAvailability.isEmpty
                        ? null
                        : data.sharedAvailability,
                    personName: data.displayName,
                  ),
                ],

                // Justo debajo del horario y encima de todo lo demás que
                // esta persona ha escrito de sí misma: es el único dato de la
                // ficha que no lo pone su dueño, y ahí está su valor.
                if (data.levelVerdict != null) ...[
                  const SizedBox(height: 20),
                  _levelVerdictRow(context),
                ],

                if (data.intention != null) ...[
                  const SizedBox(height: 24),
                  Text('A qué viene', style: context.textStyles.titleMedium),
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
                      ? 'Todavía no has escrito nada.'
                      : data.bio!,
                  style: context.textStyles.bodyMedium,
                ),

                if (_hasExperience) ...[
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
                    _infoRow(context, Icons.emoji_events_outlined, achievement),
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

                // Dos cifras reales, calculadas de los datos que ya tiene la
                // pantalla. Antes eran tres tarjetas —"Compañeros", "Likes" y
                // "Karma"— con un guion fijo dentro: no habia nada detras de
                // ninguna. "Karma" ademas no existe en ningun sitio del
                // producto, y "Likes" es vocabulario de app de citas, que es
                // justo de donde esta app viene huyendo. Se quedan las dos que
                // se pueden calcular y significan algo aqui: con cuanta gente
                // has conectado y cuantos partidos has jugado de verdad.
                //
                // En la ficha de otra persona son otras dos: jugados y
                // ganados. "Compañeros" no sale ahí a propósito — con cuánta
                // gente ha hecho match alguien no es asunto de quien mira.
                if (showStats && stats != null) ...[
                  Row(
                    children: [
                      if (stats!.partners != null) ...[
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Compañeros',
                            '${stats!.partners}',
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: _buildStatCard(
                          context,
                          stats!.played == 1 ? 'Partido' : 'Partidos',
                          '${stats!.played}',
                        ),
                      ),
                      if (stats!.won != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          // "(dice)" y no "Ganados" a secas: este número lo
                          // rellena esa misma persona contando sus propios
                          // partidos, así que presentarlo como un hecho sería
                          // prestarle una autoridad que no tiene. Los jugados
                          // sí la tienen — hacen falta dos para subirlos.
                          child: _buildStatCard(
                            context,
                            'Ganados (dice)',
                            '${stats!.won}',
                          ),
                        ),
                      ],
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
        child: Icon(Icons.person, size: 72, color: context.colors.outline),
      ),
    );
  }

  Widget _sportsWrap(BuildContext context, List<Sport> sports) {
    if (sports.isEmpty) {
      return Text(
        'Todavía no ha elegido deportes.',
        style: context.textStyles.bodyMedium?.copyWith(
          color: context.colors.outline,
        ),
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

  bool get _hasExperience =>
      data.yearsPlaying != null ||
      (data.club ?? '').isNotEmpty ||
      data.avgPaceMinPerKm != null ||
      data.avgDistanceKm != null ||
      data.achievements.isNotEmpty;

  /// Lo que opinan los demás de su nivel.
  ///
  /// Se enseña con el color según lo que digan: verde si confirman, ámbar si
  /// discrepan hacia cualquier lado. Y **sin porcentajes** — con estas cifras
  /// un "60%" suena a estadística y son tres partidos; se habla de personas.
  Widget _levelVerdictRow(BuildContext context) {
    final verdict = data.levelVerdict!;
    final colors = context.colors;
    final agrees = verdict == LevelVerdict.accurate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: agrees ? colors.primaryContainer : colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            agrees ? Icons.verified_outlined : Icons.swap_vert,
            size: 20,
            color: agrees
                ? colors.onPrimaryContainer
                : colors.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verdict.label(data.levelVotes, mine: data.isMine),
              style: context.textStyles.bodyMedium?.copyWith(
                color: agrees
                    ? colors.onPrimaryContainer
                    : colors.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
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
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.2),
        ),
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

/// Las cifras de un perfil, propio o de otra persona.
class ProfileStats {
  /// Con cuanta gente has conectado (matches). **Sólo en el perfil propio**:
  /// de otra persona no se sabe ni se debe — con cuánta gente ha hecho match
  /// alguien no es asunto de quien mira su ficha.
  final int? partners;

  /// Partidos jugados de verdad: los que alguna de las dos partes confirmo
  /// que ocurrieron. No propuestos ni aceptados — jugados.
  final int played;

  /// Partidos que dice haber ganado. `null` cuando no aplica (perfil propio,
  /// donde la pantalla ya enseña el historial completo con sus resultados).
  ///
  /// Es **auto-declarado**, a diferencia de [played], que necesita a otra
  /// persona para subir. Por eso en la ficha va etiquetado como "Ganados
  /// (dice)": enseñarlo con la misma autoridad que los jugados convertiría
  /// la app en una tabla de mentiras cómodas.
  final int? won;

  const ProfileStats({this.partners, required this.played, this.won});
}
