import 'package:match_point/core/analytics/analytics.dart';
import 'package:flutter/material.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/network/notification_counts.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/date_format_es.dart';
import 'package:match_point/core/ui/widgets/error_state_view.dart';
import 'package:match_point/core/ui/widgets/screen_header.dart';
import 'package:match_point/core/ui/profile/network_photo.dart';
import 'package:match_point/core/utils/app_sports.dart';
import 'package:match_point/core/utils/sport_words.dart';

import '../../discovery/models/sport.dart';
import '../models/proposal.dart';
import '../services/proposal_service.dart';
import 'session_detail_screen.dart';

/// "Qué juego próximamente" — lo que convierte MatchPoint de "he hecho
/// match con alguien" a "tengo partido el jueves".
///
/// Se llama "Quedadas" y no "Partidos" porque la app entrelaza tenis y
/// correr: a quien sólo corre, una pestaña llamada "Partidos" le hablaba
/// de algo que no hace (ver `core/utils/sport_words.dart`).
///
/// Muestra tanto lo ya acordado como lo que sigue en el aire. Las
/// propuestas pendientes solían vivir únicamente dentro del chat que las
/// traía, así que una propuesta sin abrir no aparecía en la única pantalla
/// que se supone que contesta "¿qué tengo por jugar?".
class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  final _service = ProposalService(Api.client);

  List<UpcomingSession> _sessions = const [];

  /// Quedadas ya pasadas que esperan que cuentes que ocurrio. Van arriba del
  /// todo: es lo unico de esta pantalla que se pierde si no se contesta
  /// pronto — nadie recuerda un partido de hace tres semanas.
  List<UpcomingSession> _toConfirm = const [];

  /// Lo ya jugado. Va abajo del todo: primero lo que hay que hacer, después
  /// lo que ya pasó.
  List<PlayedSession> _history = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // En paralelo: son dos endpoints independientes y encadenarlos solo
      // haria esperar el doble.
      // En paralelo: son endpoints independientes y encadenarlos sólo haría
      // esperar el triple.
      final upcoming = _service.listUpcoming();
      final toConfirm = _service.listAwaitingFeedback();
      // El historial no puede tumbar la pantalla: si falla, se ve la agenda
      // igual y simplemente no hay sección de jugados.
      final history = _service.listHistory().catchError(
        (_) => <PlayedSession>[],
      );

      final results = await Future.wait([upcoming, toConfirm]);
      final past = await history;
      if (!mounted) return;
      setState(() {
        _sessions = results[0];
        _toConfirm = results[1];
        _history = past;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Se guarda el error entero y no su texto: `ErrorStateView` necesita
        // el tipo para saber si es un problema de red.
        _error = e;
        _loading = false;
      });
    }
  }

  /// Abre la ficha de la quedada, no el chat: tocar una sesión para acabar
  /// en una conversación donde hay que reconstruir cuándo y dónde era
  /// tenía poco sentido. Desde la ficha se puede saltar al chat.
  Future<void> _openDetail(UpcomingSession session) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
    );
    // Puede haberse aceptado, rechazado o cancelado desde dentro.
    if (mounted) {
      await _load();
      NotificationCounts.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Misma cabecera que Descubrir y Compañeros (ver `ScreenHeader`): las
      // tres pantallas de la barra se leían como de apps distintas porque
      // ésta y Compañeros usaban un `AppBar` de Material y Descubrir no.
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Tus partidos'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorStateView(error: _error!, onRetry: _load);
    }

    if (_sessions.isEmpty && _toConfirm.isEmpty) {
      // ListView (no Center pelado) para que el pull-to-refresh siga
      // funcionando con la lista vacía.
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.event_available_outlined,
            size: 64,
            color: context.colors.outline,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Todavía no tienes nada agendado',
              style: context.textStyles.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Cuando propongas jugar a alguno de tus compañeros (o te lo '
              'propongan a ti), lo verás aquí.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    // Lo que espera algo de ti va primero: es lo único de esta pantalla
    // que se queda parado hasta que actúes.
    final needsAnswer = _sessions
        .where((s) => s.proposal.isPending && !s.proposal.mine)
        .toList();
    final waiting = _sessions
        .where((s) => s.proposal.isPending && s.proposal.mine)
        .toList();
    final confirmed = _sessions
        .where((s) => s.proposal.status == ProposalStatus.accepted)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_toConfirm.isNotEmpty) ..._confirmSection(context),
        if (needsAnswer.isNotEmpty)
          ..._section(context, 'Esperan tu respuesta', needsAnswer),
        if (confirmed.isNotEmpty)
          ..._section(context, 'Confirmadas', confirmed),
        if (waiting.isNotEmpty)
          ..._section(context, 'Esperando respuesta', waiting),
        if (_history.isNotEmpty) ..._historySection(context),
      ],
    );
  }

  /// Lo ya jugado, del más reciente al más antiguo.
  ///
  /// Va al final a propósito: arriba está lo que pide una acción tuya y lo
  /// que tienes por delante; esto es para mirar, no para hacer. Pero tiene
  /// que estar — sin ello, la app tira todo lo que has jugado en cuanto pasa,
  /// que es justamente la prueba de que sirve para algo.
  List<Widget> _historySection(BuildContext context) {
    return [
      _SectionTitle('Terminados (${_history.length})'),
      for (final s in _history)
        _PlayedRow(
          key: ValueKey(s.proposal.id),
          session: s,
        ),
    ];
  }

  /// Seccion de "cuenta que paso". Va primero en la lista.
  List<Widget> _confirmSection(BuildContext context) {
    return [
      _SectionTitle('¿Qué tal fue? (${_toConfirm.length})'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Contarlo es lo que hace que los niveles del resto signifiquen algo.',
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
      for (final session in _toConfirm)
        _ConfirmCard(
          key: ValueKey(session.proposal.id),
          session: session,
          onAnswer: ({required played, outcome, wouldRepeat}) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _service.saveFeedback(
                proposalId: session.proposal.id,
                played: played,
                outcome: outcome,
                wouldRepeat: wouldRepeat,
              );
              // La metrica que de verdad mide si esta app sirve: no
              // registros ni matches, partidos jugados.
              Analytics.sessionPlayed(played: played);
              // Recargar y no quitar la tarjeta a mano: el badge de la barra
              // sale del servidor, y dejarlos calculando por separado es
              // como se desincronizan.
              await _load();
              NotificationCounts.instance.refresh();
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                ),
              );
            }
          },
        ),
    ];
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<UpcomingSession> sessions,
  ) {
    return [
      _SectionTitle('$title (${sessions.length})'),
      for (final session in sessions) _sessionTile(context, session),
    ];
  }

  Widget _sessionTile(BuildContext context, UpcomingSession session) {
    final proposal = session.proposal;
    final photo = session.otherPhoto;
    final colors = context.colors;
    final needsAnswer = proposal.isPending && !proposal.mine;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      // Sin borde salvo cuando espera respuesta tuya: el tema ya le pone
      // sombra a las tarjetas, y borde más sombra a la vez es ruido — mismo
      // criterio que las filas de Descubrir. Si todas destacan, no destaca
      // ninguna.
      shape: needsAnswer
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: colors.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () => _openDetail(session),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cuadrado redondeado y no círculo, igual que en Compañeros:
              // el círculo es la convención de las apps de citas, y esto se
              // lee como ficha. Era lo que más desentonaba de la pantalla.
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photo == null
                      ? Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_outline,
                            color: colors.outline,
                          ),
                        )
                      : NetworkPhoto(url: photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // El icono del deporte sólo si hay más de uno: una
                        // raqueta en cada fila de una app de tenis no
                        // distingue nada (ver `app_sports.dart`).
                        if (!isSingleSportApp) ...[
                          Icon(
                            sportIcon(proposal.sport),
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            session.otherDisplayName,
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatProposalDateTime(proposal.scheduledAt),
                      style: context.textStyles.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (proposal.placeName != null)
                      Text(
                        proposal.placeName!,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (needsAnswer) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Acepta o rechaza',
                        style: context.textStyles.labelMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de "cuenta que paso".
///
/// Va arriba del todo de la pantalla a proposito: es lo unico aqui que se
/// pierde si no se contesta pronto, porque nadie recuerda como fue un
/// partido de hace tres semanas. Y es lo que sostiene la promesa del
/// producto — sin esto el nivel que cada uno declara no lo corrige nunca
/// nada.
class _ConfirmCard extends StatefulWidget {
  final UpcomingSession session;
  final Future<void> Function({
    required bool played,
    String? outcome,
    bool? wouldRepeat,
  })
  onAnswer;

  const _ConfirmCard({
    super.key,
    required this.session,
    required this.onAnswer,
  });

  @override
  State<_ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends State<_ConfirmCard> {
  bool _busy = false;

  /// null = todavia no ha dicho si jugaron. Al decir que si, la tarjeta
  /// pregunta el resto en el sitio, sin abrir otra pantalla: son dos toques
  /// y sacarlos a un formulario aparte haria que nadie los diera.
  bool? _played;
  String? _outcome;

  bool get _isTennis => widget.session.proposal.sport == Sport.tennis;

  Future<void> _send({required bool played, bool? wouldRepeat}) async {
    setState(() => _busy = true);
    try {
      await widget.onAnswer(
        played: played,
        outcome: played ? _outcome : null,
        wouldRepeat: played ? wouldRepeat : null,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final noun = sportSessionNoun(s.proposal.sport);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sportIcon(s.proposal.sport), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$noun con ${s.otherDisplayName}',
                    style: context.textStyles.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _whenLabel(s.proposal.scheduledAt),
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_played == null) ...[
              Text('¿Llegasteis a jugar?', style: context.textStyles.bodyLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => setState(() => _played = true),
                      child: const Text('Sí, jugamos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _send(played: false),
                      child: const Text('No pudo ser'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              if (_isTennis) ...[
                Text('¿Cómo acabó?', style: context.textStyles.bodyLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const [
                      ('WON', 'Gané'),
                      ('LOST', 'Perdí'),
                      ('TIED', 'Empate'),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        selected: _outcome == option.$1,
                        onSelected: (_) => setState(() => _outcome = option.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '¿Repetirías con ${s.otherDisplayName}?',
                style: context.textStyles.bodyLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _send(played: true, wouldRepeat: true),
                      child: const Text('Sí'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _send(played: true, wouldRepeat: false),
                      child: const Text('No'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _whenLabel(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return 'Hoy';
    if (days == 1) return 'Ayer';
    return 'Hace $days días';
  }
}

/// Una fila del historial: contra quién, cuándo y cómo acabó.
class _PlayedRow extends StatelessWidget {
  final PlayedSession session;

  const _PlayedRow({super.key, required this.session});

  /// Verde ganado, rojo perdido, neutro el resto. El color hace el trabajo
  /// de un vistazo; la palabra está al lado para quien no lo distinga.
  (Color, Color) _colors(BuildContext context) {
    final c = context.colors;
    return switch (session.outcome) {
      'WON' => (c.primaryContainer, c.onPrimaryContainer),
      'LOST' => (c.errorContainer, c.onErrorContainer),
      _ => (c.surfaceContainerHighest, c.onSurfaceVariant),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final colors = context.colors;
    final photo = session.otherPhoto;
    final label = session.outcomeLabel;
    final (badgeBg, badgeFg) = _colors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: photo == null
                  ? Container(
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_outline,
                        color: colors.outline,
                        size: 20,
                      ),
                    )
                  : NetworkPhoto(url: photo, fit: BoxFit.cover, iconSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.otherDisplayName,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatPastDate(session.proposal.scheduledAt),
                  style: t.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                label,
                style: t.labelMedium?.copyWith(
                  color: badgeFg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (session.played == false)
            Text(
              'No se jugó',
              style: t.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          else
            // Ni contestado ni sabido: se dice, en vez de dejar el hueco.
            Text(
              'Sin contestar',
              style: t.labelMedium?.copyWith(color: colors.outline),
            ),
        ],
      ),
    );
  }
}

/// El título de cada sección de la pantalla.
///
/// Existe porque había tres formatos distintos conviviendo — dos tamaños, dos
/// colores y dos sangrados — y era justo lo que hacía que Partidos se leyera
/// como de otra app comparada con Descubrir y Compañeros.
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text,
        style: context.textStyles.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
