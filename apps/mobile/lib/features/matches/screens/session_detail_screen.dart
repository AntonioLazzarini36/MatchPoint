import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/date_format_es.dart';
import 'package:match_point/core/ui/dialogs/confirm_dialog.dart';

import '../models/proposal.dart';
import '../services/matches_service.dart';
import '../services/proposal_service.dart';
import '../../discovery/models/discover_profile.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/services/profile_service.dart';

/// Ficha de un partido acordado: cuando, donde, contra quien.
///
/// Antes tocar una sesion en "Proximos partidos" llevaba directo al chat,
/// que es justo donde NO esta la informacion (hay que reconstruirla
/// scrolleando). Aqui esta todo junto, y el chat es una accion mas.
class SessionDetailScreen extends StatefulWidget {
  final UpcomingSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Proposal _proposal = widget.session.proposal;

  /// Perfil completo del rival — se pide aparte porque la lista de
  /// proximas sesiones solo trae nombre y foto (lo justo para pintar una
  /// fila sin una segunda llamada por cada una).
  DiscoverProfile? _opponent;
  bool _loadingOpponent = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadOpponent();
  }

  Future<void> _loadOpponent() async {
    try {
      final profile = await ProfileService(
        Api.client,
      ).getUserProfile(widget.session.otherUserId);
      if (!mounted) return;
      setState(() {
        _opponent = profile;
        _loadingOpponent = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOpponent = false);
    }
  }

  Future<void> _openChat() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final matches = await MatchesService(Api.client).fetchMatches();
      final match = matches.firstWhere((m) => m.matchId == _proposal.matchId);
      if (!mounted) return;
      await context.push<bool>('/chat/${match.matchId}', extra: match);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el chat')),
      );
    }
  }

  /// Cancelar algo ya acordado lo puede hacer cualquiera de los dos: los
  /// planes cambian, y obligar a no presentarse seria peor que decirlo.
  Future<void> _cancel() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Cancelar el partido?',
      content: 'Se le avisará a ${widget.session.otherDisplayName}. '
          'Podéis volver a proponer otro día cuando queráis.',
      confirmLabel: 'Cancelar partido',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ProposalService(
        Api.client,
      ).respond(proposalId: _proposal.id, action: 'CANCEL');
      if (!mounted) return;
      setState(() => _proposal = updated);
      messenger.showSnackBar(
        const SnackBar(content: Text('Partido cancelado')),
      );
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final styles = context.textStyles;
    final cancelled = _proposal.status != ProposalStatus.accepted;

    return Scaffold(
      appBar: AppBar(title: const Text('Partido')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _headerCard(context),
          const SizedBox(height: 16),

          if (_proposal.placeName != null) ...[
            Text('Dónde', style: styles.titleSmall),
            const SizedBox(height: 8),
            _placeCard(context),
            const SizedBox(height: 16),
          ],

          Text('Tu rival', style: styles.titleSmall),
          const SizedBox(height: 8),
          _opponentCard(context),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _busy ? null : _openChat,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Abrir chat'),
          ),
          const SizedBox(height: 8),
          if (!cancelled)
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              ),
              icon: const Icon(Icons.event_busy, size: 18),
              label: const Text('Cancelar partido'),
            ),
        ],
      ),
    );
  }

  /// Cuándo y qué deporte, en grande — es lo que uno viene a mirar.
  Widget _headerCard(BuildContext context) {
    final colors = context.colors;
    final styles = context.textStyles;
    final isTennis = _proposal.sport == Sport.tennis;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isTennis ? Icons.sports_tennis : Icons.directions_run,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                isTennis ? 'Partido de tenis' : 'Salida a correr',
                style: styles.titleSmall?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatProposalDateTime(_proposal.scheduledAt),
            style: styles.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _countdownLabel(),
            style: styles.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// "Dentro de 3 días" se lee de un vistazo; una fecha absoluta obliga a
  /// hacer la cuenta mentalmente.
  String _countdownLabel() {
    final diff = _proposal.scheduledAt.difference(DateTime.now());
    if (diff.isNegative) return 'Ya ha empezado';
    if (diff.inHours < 1) return 'En menos de una hora';
    if (diff.inHours < 24) return 'Dentro de ${diff.inHours} h';
    final days = diff.inDays;
    return days == 1 ? 'Mañana' : 'Dentro de $days días';
  }

  Widget _placeCard(BuildContext context) {
    final colors = context.colors;
    final styles = context.textStyles;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.surfaceContainerHighest),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Mini-mapa embebido en vez de un enlace a otra app: se ve de un
          // vistazo si el sitio queda cerca sin salir de MatchPoint.
          if (_proposal.hasCoordinates)
            SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    _proposal.placeLat!,
                    _proposal.placeLng!,
                  ),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.matchpoint.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _proposal.placeLat!,
                          _proposal.placeLng!,
                        ),
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_on,
                          color: colors.primary,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ListTile(
            leading: Icon(Icons.place_outlined, color: colors.primary),
            title: Text(_proposal.placeName!, style: styles.bodyLarge),
          ),
        ],
      ),
    );
  }

  Widget _opponentCard(BuildContext context) {
    final colors = context.colors;
    final styles = context.textStyles;
    final opponent = _opponent;
    final photo = opponent?.mainPhoto ?? widget.session.otherPhoto;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.otherDisplayName,
                      style: styles.titleMedium,
                    ),
                    if (opponent?.city != null)
                      Text(
                        opponent!.city!,
                        style: styles.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (_loadingOpponent)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (opponent != null) ...[
            const SizedBox(height: 12),
            _opponentFacts(context, opponent),
          ],
        ],
      ),
    );
  }

  /// Las señales que responden "¿juega a mi nivel?" — que es justo el
  /// motivo por el que existe la app (ver el reposicionamiento en
  /// status.md), no un adorno del perfil.
  Widget _opponentFacts(BuildContext context, DiscoverProfile opponent) {
    final colors = context.colors;
    final level = opponent.skillLevels[_proposal.sport];
    final isTennis = _proposal.sport == Sport.tennis;

    final facts = <(IconData, String)>[
      if (level != null) (Icons.military_tech_outlined, level.label),
      if (isTennis && opponent.yearsPlaying != null)
        (Icons.timeline, '${opponent.yearsPlaying} años jugando'),
      if (isTennis && opponent.club != null)
        (Icons.groups_outlined, opponent.club!),
      if (!isTennis && opponent.avgDistanceKm != null)
        (Icons.straighten, '${opponent.avgDistanceKm} km de media'),
      if (opponent.achievements.isNotEmpty)
        (Icons.emoji_events_outlined, opponent.achievements.first),
    ];

    if (facts.isEmpty) {
      return Text(
        'Todavía no ha rellenado su experiencia.',
        style: context.textStyles.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label) in facts)
          Chip(
            avatar: Icon(icon, size: 16),
            label: Text(label),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
