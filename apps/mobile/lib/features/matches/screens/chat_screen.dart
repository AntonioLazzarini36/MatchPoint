import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:match_point/app/routes.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/network/notification_counts.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/app_sports.dart';
import 'package:match_point/core/utils/sport_words.dart';

import '../chat_controller.dart';
import '../services/chat_service.dart';
import '../services/matches_service.dart';
import '../../onboarding/services/profile_service.dart';

import '../../../core/ui/dialogs/confirm_dialog.dart';
import '../../../core/ui/dialogs/report_reason_dialog.dart';
import '../../../core/ui/widgets/chat/chat_message_bubble.dart';
import '../../../core/ui/widgets/chat/chat_input_bar.dart';
import '../../../core/ui/widgets/proposal/propose_session.dart';
import '../../../core/ui/widgets/proposal/proposal_bubble.dart';
import '../models/chat_message.dart';
import '../models/proposal.dart';
import '../services/proposal_service.dart';
import 'session_detail_screen.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/models/availability.dart';
import '../../../core/network/connection_error.dart';
import 'package:match_point/core/i18n/app_locale.dart';

enum _ChatMenuAction { courts, unmatch, report }

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String myUserId;
  final String otherUserId;
  final String otherName;
  final String? otherPhotoUrl;
  final Sport sport;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.myUserId,
    required this.otherUserId,
    required this.otherName,
    required this.sport,
    this.otherPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController controller;
  late final MatchesService matchesService;
  late final ProfileService profileService;
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();

  bool _busy = false;

  /// Deportes de cada uno, para saber cuáles compartís. `null` = todavía
  /// no han llegado.
  List<Sport>? _mySports;
  List<Sport>? _theirSports;

  /// El horario semanal habitual de la otra persona, para enseñarlo al
  /// proponer. Llega con el perfil; hasta entonces se propone sin el.
  WeeklyAvailability? _theirAvailability;
  WeeklyAvailability? _myAvailability;
  Timer? _pollTimer;

  /// La propuesta más reciente del match, fijada arriba del chat. null
  /// mientras no haya ninguna. Se refresca junto con los mensajes: la otra
  /// persona puede aceptarla desde su móvil mientras miras la pantalla.
  List<Proposal> _proposals = const [];
  late final ProposalService proposalService;

  @override
  void initState() {
    super.initState();
    controller = ChatController(
      service: ChatService(Api.client),
      matchId: widget.matchId,
    );
    matchesService = MatchesService(Api.client);
    profileService = ProfileService(Api.client);
    proposalService = ProposalService(Api.client);
    controller.init().then((_) => _scrollToBottom());
    _loadProposal();
    _loadSharedSports();

    // No websocket/push here — short-interval polling is enough for this
    // app's scale, and far less machinery than standing up a socket.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final before = controller.messages.length;
      final wasNearBottom = _isNearBottom();
      await controller.pollNewMessages();
      if (!mounted) return;
      if (controller.messages.length > before && wasNearBottom) {
        _scrollToBottom();
      }
      await _loadProposal();
    });
  }

  /// Silenciosa a propósito: si falla (red intermitente), el chat sigue
  /// siendo perfectamente usable, y el siguiente tick lo reintenta. No
  /// merece un banner de error encima de la conversación.
  /// **Todas** las propuestas del match, vivas y resueltas.
  ///
  /// Van dentro de la conversación como un mensaje más (ver
  /// `_buildMessages`), así que una cancelada no se descarta: se queda donde
  /// ocurrió, tachada, igual que quedaría "quedamos el jueves — al final no
  /// puedo" si se hubiera hablado por texto.
  Future<void> _loadProposal() async {
    try {
      final all = await proposalService.listForMatch(widget.matchId);
      if (!mounted) return;
      setState(() => _proposals = all);
    } catch (_) {
      // se reintenta en el siguiente poll
    }
  }

  /// Abre **la misma pantalla** que la pestaña de Partidos.
  ///
  /// Llegué a escribir una ficha aparte para esto, y era un error: enseñaba
  /// lo mismo que `SessionDetailScreen` —cuándo, cuánto falta, dónde con el
  /// mini-mapa, y aceptar/rechazar/retirar— pero con otra forma. Dos
  /// pantallas distintas para el mismo contenido significan mantener las dos
  /// y que se separen a la primera de cambio, que es exactamente lo que ya
  /// había pasado con los colores de estado.
  ///
  /// La única diferencia real era que una salía como hoja y la otra a
  /// pantalla completa, y eso no justifica duplicar nada.
  Future<void> _openProposal(Proposal proposal) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(
          session: UpcomingSession(
            proposal: proposal,
            otherUserId: widget.otherUserId,
            otherDisplayName: widget.otherName,
            otherPhoto: widget.otherPhotoUrl,
          ),
        ),
      ),
    );
    // Puede haberse aceptado, rechazado o retirado ahí dentro.
    if (!mounted) return;
    await _loadProposal();
    NotificationCounts.instance.refresh();
  }

  Future<void> _propose(Sport sport) async {
    final created = await proposeSession(
      context,
      matchId: widget.matchId,
      sport: sport,
      // Puede ser null si el perfil aun no ha llegado: entonces los pasos de
      // dia y hora salen como siempre, sin referencia de horario.
      otherAvailability: _theirAvailability,
      myAvailability: _myAvailability,
      otherName: widget.otherName,
    );
    if (created && mounted) await _loadProposal();
  }

  /// Deportes que podéis jugar juntos: los que practicáis los dos.
  ///
  /// El deporte del match sólo dice por qué feed os cruzasteis. Si los dos
  /// jugáis al tenis y además coréis, no hay motivo para que en esta
  /// conversación sólo se pueda proponer tenis — antes el deporte del
  /// match mandaba y el otro no existía por ningún lado.
  ///
  /// Mientras no lleguen los perfiles se usa el del match, que siempre es
  /// válido: así el botón funciona desde el primer frame en vez de
  /// aparecer medio segundo después.
  ///
  /// `onlyEnabled` recorta además a los deportes que la app ofrece hoy: hay
  /// cuentas de cuando se podía elegir correr, y sin ese recorte a dos de
  /// ellas les saldría un botón de proponer una salida en una app que ya no
  /// habla de correr por ningún otro sitio.
  List<Sport> get _sharedSports {
    final mine = _mySports;
    final theirs = _theirSports;
    if (mine == null || theirs == null) return onlyEnabled([widget.sport]);
    final shared = mine.where(theirs.contains).toList();
    return onlyEnabled(shared.isEmpty ? [widget.sport] : shared);
  }

  Future<void> _loadSharedSports() async {
    try {
      final service = ProfileService(Api.client);
      final me = await service.getMe();
      final other = await service.getUserProfile(widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _mySports = me.profile?.sports ?? const [];
        _theirSports = other.sports;
        _theirAvailability = other.availability;
        // El mio hace falta para cruzar los dos horarios y sugerir huecos
        // concretos al proponer (ver `suggestSlots`).
        _myAvailability = me.profile?.availability;
      });
    } catch (_) {
      // Se queda con el deporte del match, que es lo que había antes.
    }
  }

  bool _isNearBottom() {
    if (!scroll.hasClients) return true;
    const threshold = 120.0;
    return scroll.position.maxScrollExtent - scroll.position.pixels < threshold;
  }

  /// A diferencia de [_report], unmatch sí cierra el chat, devolviendo
  /// `true` para que `MatchesScreen` sepa que tiene que recargar la lista.
  Future<void> _unmatch() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.current.unmatch,
      content:
          S.current.unmatchConfirmNoName,
      confirmLabel: S.current.unmatch,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await matchesService.unmatch(widget.matchId);
      if (!mounted) return;
      router.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              e,
              fallback: S.current.couldNotCompleteOperation,
            ),
          ),
        ),
      );
      setState(() => _busy = false);
    }
  }

  /// Reportar no borra el match — a diferencia de unmatch, se queda en el
  /// chat en vez de cerrarlo.
  Future<void> _report() async {
    final reason = await showReportReasonDialog(context);
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await profileService.reportUser(widget.otherUserId, reason);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(S.current.reportSent)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: S.current.couldNotSendReport),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                context.pushNamed(
                  AppRoutes.userProfileName,
                  pathParameters: {'userId': widget.otherUserId},
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: context.colors.primaryContainer,
                    backgroundImage: widget.otherPhotoUrl == null
                        ? null
                        : NetworkImage(widget.otherPhotoUrl!),
                    child: widget.otherPhotoUrl == null
                        ? Icon(Icons.person, color: context.colors.primary)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(widget.otherName, style: context.textStyles.titleMedium),
                ],
              ),
            ),
            centerTitle: true,
            actions: [
              // Un botón por deporte que podáis jugar juntos. Con uno solo
              // en común es exactamente lo de antes; con los dos, aparecen
              // los dos iconos en vez de que el tenis se coma al otro.
              for (final sport in _sharedSports)
                IconButton(
                  tooltip: sport == Sport.running
                      ? S.current.proposeARun
                      : S.current.proposeAMatch,
                  icon: Icon(sportIcon(sport)),
                  onPressed: _busy ? null : () => _propose(sport),
                ),
              PopupMenuButton<_ChatMenuAction>(
                enabled: !_busy,
                onSelected: (action) {
                  switch (action) {
                    case _ChatMenuAction.courts:
                      context.push(AppRoutes.courtsMap);
                    case _ChatMenuAction.unmatch:
                      _unmatch();
                    case _ChatMenuAction.report:
                      _report();
                  }
                },
                itemBuilder: (context) => [
                  // El mapa de clubes vivia en la AppBar de Matches, donde
                  // aparecia con cada conversacion aunque fuera de correr.
                  // Aqui sale solo en un chat de tenis, que es cuando mirar
                  // pistas cerca viene a cuento.
                  if (widget.sport == Sport.tennis)
                    PopupMenuItem(
                      value: _ChatMenuAction.courts,
                      child: Text(S.current.seeCourtsNearby),
                    ),
                  PopupMenuItem(
                    value: _ChatMenuAction.unmatch,
                    child: Text(S.current.unmatch),
                  ),
                  PopupMenuItem(
                    value: _ChatMenuAction.report,
                    child: Text(S.current.report),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessages(context)),
              ChatInputBar(
                controller: input,
                sending: controller.sending,
                onSend: () async {
                  final text = input.text;
                  if (text.trim().isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);

                  input.clear();
                  try {
                    await controller.send(text);

                    if (!mounted) return;
                    _scrollToBottom();
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          friendlyError(
                            e,
                            fallback: S.current.couldNotSendMessage,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(
                S.current.couldNotLoadMessages,
                style: context.textStyles.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.reload,
                child: Text(S.current.retry),
              ),
            ],
          ),
        ),
      );
    }

    final msgs = controller.messages;
    if (msgs.isEmpty && _proposals.isEmpty) {
      return Center(
        child: Text(
          S.current.noMessagesYet,
          style: context.textStyles.titleMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    // Mensajes y propuestas en la misma línea de tiempo, ordenados por
    // cuándo ocurrieron. Una propuesta **es** un mensaje: pasó en un momento
    // de la conversación y ahí es donde tiene sentido leerla. Mezclarlas por
    // fecha es además lo que hace que varias seguidas se apilen solas.
    final items = <_TimelineItem>[
      for (final m in msgs) _TimelineItem.message(m),
      for (final p in _proposals) _TimelineItem.proposal(p),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];

        final proposal = item.proposalOrNull;
        if (proposal != null) {
          return ProposalBubble(
            key: ValueKey(proposal.id),
            proposal: proposal,
            onTap: () => _openProposal(proposal),
          );
        }

        final m = item.messageOrNull!;
        return ChatMessageBubble(
          text: m.text,
          time: _formatTime(m.createdAt),
          isMe: m.senderId == widget.myUserId,
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}

/// Una entrada de la conversación: o un mensaje, o una propuesta.
///
/// Existe sólo para poder ordenar las dos cosas juntas por fecha sin
/// inventarse una clase base común entre dos modelos que no la necesitan
/// para nada más.
class _TimelineItem {
  final DateTime at;
  final ChatMessage? _message;
  final Proposal? _proposal;

  _TimelineItem.message(ChatMessage m)
    : at = m.createdAt,
      _message = m,
      _proposal = null;

  /// Por `createdAt`, no por `scheduledAt`: lo que ordena la conversación es
  /// cuándo se propuso, no para cuándo era. Una propuesta hecha hoy para
  /// dentro de un mes va al final del chat, que es donde se escribió.
  _TimelineItem.proposal(Proposal p)
    : at = p.createdAt,
      _message = null,
      _proposal = p;

  ChatMessage? get messageOrNull => _message;
  Proposal? get proposalOrNull => _proposal;
}
