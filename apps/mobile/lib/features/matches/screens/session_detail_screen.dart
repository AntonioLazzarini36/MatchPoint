import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/network/notification_counts.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/date_format_es.dart';
import 'package:match_point/core/utils/sport_words.dart';
import 'package:match_point/core/ui/dialogs/confirm_dialog.dart';

import '../models/proposal.dart';
import '../services/matches_service.dart';
import '../services/proposal_service.dart';
import '../../discovery/models/discover_profile.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/services/profile_service.dart';

/// Ficha de una quedada: cuándo, dónde, contra quién — y, si todavía no
/// está cerrada, los botones que la cierran.
///
/// Antes tocar una sesión en la pestaña de quedadas llevaba directo al
/// chat, que es justo donde NO está la información (hay que reconstruirla
/// scrolleando). Aquí está todo junto, y el chat es una acción más.
///
/// Acepta también propuestas PENDIENTES, no sólo aceptadas: hasta ahora
/// sólo se podían responder desde dentro del chat que las traía, así que
/// una propuesta sin abrir era invisible justo en la pantalla que lista lo
/// que tienes por jugar.
class SessionDetailScreen extends StatefulWidget {
  final UpcomingSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Proposal _proposal = widget.session.proposal;

  /// Perfil completo del rival — se pide aparte porque la lista de
  /// quedadas sólo trae nombre y foto (lo justo para pintar una fila sin
  /// una segunda llamada por cada una).
  DiscoverProfile? _opponent;
  bool _loadingOpponent = true;
  bool _busy = false;

  /// True si algo cambió de estado aquí dentro, para que la pantalla de
  /// la que venimos se recargue al volver.
  bool _changed = false;

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

  /// Un único camino para las tres transiciones: el backend es quien
  /// decide si la acción está permitida (y devuelve el motivo si no), así
  /// que el cliente no repite esas reglas, sólo las presenta.
  Future<void> _respond(String action, {String? successMessage}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ProposalService(
        Api.client,
      ).respond(proposalId: _proposal.id, action: action);
      if (!mounted) return;
      setState(() {
        _proposal = updated;
        _changed = true;
      });
      // Responder cambia el badge de la barra de navegación: refrescarlo
      // ya evita que siga marcando algo que acabas de resolver.
      NotificationCounts.instance.refresh();
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cancelar algo ya acordado lo puede hacer cualquiera de los dos: los
  /// planes cambian, y obligar a no presentarse sería peor que decirlo.
  Future<void> _cancel() async {
    final noun = sportSessionNoun(_proposal.sport);
    final accepted = _proposal.status == ProposalStatus.accepted;
    final confirmed = await showConfirmDialog(
      context,
      title: accepted ? '¿Cancelar el $noun?' : '¿Retirar la propuesta?',
      content: accepted
          ? 'Se le avisará a ${widget.session.otherDisplayName}. '
                'Podéis volver a proponer otro día cuando queráis.'
          : 'La propuesta desaparecerá para '
                '${widget.session.otherDisplayName}.',
      confirmLabel: accepted ? 'Cancelar $noun' : 'Retirar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _respond(
      'CANCEL',
      successMessage: accepted ? 'Quedada cancelada' : 'Propuesta retirada',
    );
    // `Navigator` y no `context.pop` de go_router: esta pantalla se abre
    // con un `MaterialPageRoute` normal desde la lista de quedadas, no
    // como ruta del router.
    if (mounted && _proposal.status == ProposalStatus.cancelled) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Quedada')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _headerCard(context),
            const SizedBox(height: 16),

            if (_proposal.placeName != null) ...[
              Text('Dónde', style: context.textStyles.titleSmall),
              const SizedBox(height: 8),
              _placeCard(context),
              const SizedBox(height: 16),
            ],

            Text('Tu rival', style: context.textStyles.titleSmall),
            const SizedBox(height: 8),
            _opponentCard(context),
            const SizedBox(height: 24),

            ..._actions(context),
          ],
        ),
      ),
    );
  }

  /// Los botones dependen del estado y de quién hizo la propuesta — las
  /// mismas reglas que la tarjeta del chat, para que responder desde aquí
  /// o desde allí se sienta igual.
  List<Widget> _actions(BuildContext context) {
    final colors = context.colors;
    final noun = sportSessionNoun(_proposal.sport);

    if (_busy) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    final chat = FilledButton.icon(
      onPressed: _openChat,
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: const Text('Abrir chat'),
    );

    switch (_proposal.status) {
      // Sólo quien la recibe puede aceptar o rechazar.
      case ProposalStatus.pending when !_proposal.mine:
        return [
          FilledButton.icon(
            onPressed: () =>
                _respond('ACCEPT', successMessage: 'Quedada confirmada'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Aceptar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                _respond('DECLINE', successMessage: 'Propuesta rechazada'),
            child: const Text('Rechazar'),
          ),
          const SizedBox(height: 8),
          chat,
        ];

      // La hiciste tú: sólo puedes retirarla.
      case ProposalStatus.pending:
        return [
          chat,
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Retirar propuesta'),
          ),
        ];

      case ProposalStatus.accepted:
        return [
          chat,
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
            ),
            icon: const Icon(Icons.event_busy, size: 18),
            label: Text('Cancelar $noun'),
          ),
        ];

      case ProposalStatus.declined:
      case ProposalStatus.cancelled:
        return [chat];
    }
  }

  /// Cuándo, qué deporte y en qué punto está — es lo que uno viene a
  /// mirar. El color de fondo cambia con el estado para que "confirmada" y
  /// "esperando" no se confundan de un vistazo.
  Widget _headerCard(BuildContext context) {
    final colors = context.colors;
    final styles = context.textStyles;
    final confirmed = _proposal.status == ProposalStatus.accepted;
    final closed =
        _proposal.status == ProposalStatus.declined ||
        _proposal.status == ProposalStatus.cancelled;

    final background = closed
        ? colors.surfaceContainerHighest
        : confirmed
        ? colors.primaryContainer
        : colors.secondaryContainer;
    final foreground = closed
        ? colors.onSurface
        : confirmed
        ? colors.onPrimaryContainer
        : colors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sportIcon(_proposal.sport), color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sportSessionTitle(_proposal.sport),
                  style: styles.titleSmall?.copyWith(color: foreground),
                ),
              ),
              _statusBadge(context, foreground),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatProposalDateTime(_proposal.scheduledAt),
            style: styles.headlineSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(),
            style: styles.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, Color foreground) {
    final label = switch (_proposal.status) {
      ProposalStatus.accepted => 'Confirmada',
      ProposalStatus.pending => 'Sin confirmar',
      ProposalStatus.declined => 'Rechazada',
      ProposalStatus.cancelled => 'Cancelada',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(color: foreground),
      ),
    );
  }

  /// Con la quedada cerrada la cuenta atrás no dice nada útil — mejor
  /// decir de quién se espera algo, o que ya no hay nada que esperar.
  String _subtitle() {
    switch (_proposal.status) {
      case ProposalStatus.accepted:
        return _countdownLabel();
      case ProposalStatus.pending:
        return _proposal.mine
            ? 'Esperando a ${widget.session.otherDisplayName}'
            : 'Esperando tu respuesta';
      case ProposalStatus.declined:
        return 'Ya no se juega';
      case ProposalStatus.cancelled:
        return 'Se canceló';
    }
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
  ///
  /// Van como filas con icono y no como `Chip`s: los logros son textos
  /// largos ("Subcampeón del torneo de Benalmádena 2024") y dentro de una
  /// píldora se cortan o desbordan.
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
      for (final achievement in opponent.achievements)
        (Icons.emoji_events_outlined, achievement),
    ];

    if (facts.isEmpty) {
      return Text(
        'Todavía no ha rellenado su experiencia.',
        style: context.textStyles.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, label) in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: context.textStyles.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
