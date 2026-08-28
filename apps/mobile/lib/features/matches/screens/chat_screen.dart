import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:match_point/app/routes.dart';
import 'package:match_point/core/network/api.dart';
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
import '../../../core/ui/widgets/proposal/proposal_card.dart';
import '../models/proposal.dart';
import '../services/proposal_service.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/models/availability.dart';
import '../../../core/network/connection_error.dart';

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
  bool _proposalBusy = false;
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
  /// Sólo las propuestas que siguen **vivas**: pendientes de respuesta o ya
  /// confirmadas y aún por jugar.
  ///
  /// Antes se fijaba arriba la última fuera cual fuera su estado, así que una
  /// rechazada o cancelada se quedaba ahí ocupando media pantalla con un
  /// bloque que no se puede hacer nada con él — ni cancelar ni revivir. Eso
  /// no es una acción pendiente, es historia, y su sitio es la conversación.
  ///
  /// Y ahora son varias: desde que una propuesta nueva ya no cancela la
  /// anterior, se puede tener el martes y el jueves abiertos con la misma
  /// persona, y enseñar sólo la más reciente escondía la otra.
  Future<void> _loadProposal() async {
    try {
      final all = await proposalService.listForMatch(widget.matchId);
      if (!mounted) return;
      // Un poco de margen para que una quedada no desaparezca en el
      // momento exacto de empezar.
      final cutoff = DateTime.now().subtract(const Duration(hours: 3));
      final live =
          all
              .where(
                (p) =>
                    (p.isPending || p.status == ProposalStatus.accepted) &&
                    p.scheduledAt.isAfter(cutoff),
              )
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      setState(() => _proposals = live);
    } catch (_) {
      // se reintenta en el siguiente poll
    }
  }

  Future<void> _respondToProposal(Proposal proposal, String action) async {
    setState(() => _proposalBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await proposalService.respond(
        proposalId: proposal.id,
        action: action,
      );
      if (!mounted) return;
      // Se recarga la lista entera en vez de sustituir la fila: la respuesta
      // puede sacar la propuesta de las vivas (rechazada, cancelada).
      await _loadProposal();
      if (!mounted) return;
      if (updated.status == ProposalStatus.accepted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('¡Confirmado! Ya está en tus quedadas')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _proposalBusy = false);
    }
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
      title: 'Dejar de ser compañeros',
      content:
          '¿Seguro que quieres dejar de ser compañeros? Se borrará también la '
          'conversación, y no se puede deshacer.',
      confirmLabel: 'Dejar de ser compañeros',
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
              fallback: 'No se ha podido completar la operación.',
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
      messenger.showSnackBar(const SnackBar(content: Text('Reporte enviado')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: 'No se ha podido enviar el reporte.'),
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
                      ? 'Proponer salir a correr'
                      : 'Proponer un partido',
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
                    const PopupMenuItem(
                      value: _ChatMenuAction.courts,
                      child: Text('Ver pistas cerca'),
                    ),
                  const PopupMenuItem(
                    value: _ChatMenuAction.unmatch,
                    child: Text('Dejar de ser compañeros'),
                  ),
                  const PopupMenuItem(
                    value: _ChatMenuAction.report,
                    child: Text('Reportar'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Fijadas arriba, no como una burbuja más: el problema que
              // resuelve es justo que antes la propuesta se perdía
              // scrolleando entre los mensajes. Sólo las vivas — ver
              // `_loadProposal`.
              //
              // Con más de dos, la lista propia con scroll: tres partidos
              // abiertos con la misma persona no pueden comerse la
              // conversación entera.
              if (_proposals.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.38,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final p in _proposals)
                          ProposalCard(
                            key: ValueKey(p.id),
                            proposal: p,
                            busy: _proposalBusy,
                            onAccept: () => _respondToProposal(p, 'ACCEPT'),
                            onDecline: () => _respondToProposal(p, 'DECLINE'),
                            onCancel: () => _respondToProposal(p, 'CANCEL'),
                          ),
                      ],
                    ),
                  ),
                ),
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
                            fallback: 'No se ha podido enviar el mensaje.',
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
                'No se han podido cargar los mensajes',
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
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final msgs = controller.messages;
    if (msgs.isEmpty) {
      return Center(
        child: Text(
          'Todavía no hay mensajes',
          style: context.textStyles.titleMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(16),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final m = msgs[i];

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
