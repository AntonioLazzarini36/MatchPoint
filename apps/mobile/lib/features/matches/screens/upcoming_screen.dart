import 'package:match_point/core/analytics/analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:match_point/app/routes.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/network/notification_counts.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/date_format.dart';
import 'package:match_point/core/ui/widgets/error_state_view.dart';
import 'package:match_point/core/ui/widgets/screen_header.dart';
import 'package:match_point/core/ui/profile/network_photo.dart';
import 'package:match_point/core/ui/widgets/proposal/proposal_state_style.dart';
import 'package:match_point/core/utils/app_sports.dart';
import 'package:match_point/core/utils/sport_words.dart';

import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../models/proposal.dart';
import '../services/matches_service.dart';
import '../services/proposal_service.dart';
import 'session_detail_screen.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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

  /// El nivel declarado de cada compañero, por su id. Hace falta para poder
  /// preguntar "¿juega a nivel intermedio?" en vez de soltar una lista de
  /// cuatro niveles sin contexto. Sale de `/matches`, que ya lo trae — un
  /// endpoint nuevo para esto sería una llamada por cada tarjeta.
  Map<String, SkillLevel> _levels = const {};

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

      // Los niveles tampoco pueden tumbar la pantalla: sin ellos la reseña
      // simplemente no pregunta por el nivel.
      final levels = MatchesService(Api.client)
          .fetchMatches()
          .then(
            (ms) => {
              for (final m in ms)
                if (m.otherUser.skillLevels[Sport.tennis] != null)
                  m.otherUser.userId: m.otherUser.skillLevels[Sport.tennis]!,
            },
          )
          .catchError((_) => <String, SkillLevel>{});

      final results = await Future.wait([upcoming, toConfirm]);
      final past = await history;
      final byUser = await levels;
      if (!mounted) return;
      setState(() {
        _sessions = results[0];
        _toConfirm = results[1];
        _history = past;
        _levels = byUser;
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
            ScreenHeader(title: S.current.yourMatches),
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
              S.current.nothingScheduled,
              style: context.textStyles.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              S.current.nothingScheduledHint,
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
          ..._section(context, S.current.awaitingYourAnswer, needsAnswer),
        if (confirmed.isNotEmpty)
          ..._section(
            context,
            S.current.confirmedMatches(confirmed.length),
            confirmed,
          ),
        if (waiting.isNotEmpty)
          ..._section(context, S.current.waitingForYourAnswer, waiting),
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
      _SectionTitle(S.current.finishedCount(_history.length)),
      for (final s in _history)
        _PlayedRow(key: ValueKey(s.proposal.id), session: s),
    ];
  }

  /// Seccion de "cuenta que paso". Va primero en la lista.
  List<Widget> _confirmSection(BuildContext context) {
    return [
      _SectionTitle(S.current.howDidItGoCount(_toConfirm.length)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          S.current.tellingItMakesLevelsMean,
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
      for (final session in _toConfirm)
        _ConfirmCard(
          key: ValueKey(session.proposal.id),
          session: session,
          theirLevel: _levels[session.otherUserId],
          onAnswer:
              ({
                required played,
                outcome,
                wouldRepeat,
                assessedLevel,
                skipped = false,
              }) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _service.saveFeedback(
                    proposalId: session.proposal.id,
                    played: played,
                    outcome: outcome,
                    wouldRepeat: wouldRepeat,
                    assessedLevel: assessedLevel,
                    skipped: skipped,
                  );
                  // La metrica que de verdad mide si esta app sirve: no
                  // registros ni matches, partidos jugados. Una reseña
                  // saltada no cuenta como nada: no dice que se jugara.
                  if (!skipped) Analytics.sessionPlayed(played: played);
                  // Recargar y no quitar la tarjeta a mano: el badge de la
                  // barra sale del servidor, y dejarlos calculando por
                  // separado es como se desincronizan.
                  await _load();
                  NotificationCounts.instance.refresh();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
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
      _SectionTitle(S.current.sectionCount(title, sessions.length)),
      for (final session in sessions) _sessionTile(context, session),
    ];
  }

  Widget _sessionTile(BuildContext context, UpcomingSession session) {
    return _SessionCard(
      key: ValueKey(session.proposal.id),
      session: session,
      onTap: () => _openDetail(session),
    );
  }
}

/// Una quedada, como **evento** y no como conversación.
///
/// La pantalla entera se leía como una lista de chats, y con motivo: cada
/// fila era foto grande + nombre en negrita + líneas de texto debajo, que es
/// literalmente la maqueta de WhatsApp. Con esa jerarquía, la cara mandaba y
/// el partido —cuándo y dónde, lo único que hay que saber para presentarse—
/// quedaba de texto secundario.
///
/// Así que se invierte: primero **cuándo**, en un bloque tipo hoja de
/// calendario que ninguna app de mensajes tiene; después la hora; después con
/// quién, con la foto reducida a miniatura; y por último el sitio. La cara
/// sigue ahí porque ayuda a reconocer a alguien de un vistazo, pero deja de
/// ser el titular.
class _SessionCard extends StatelessWidget {
  final UpcomingSession session;
  final VoidCallback onTap;

  const _SessionCard({super.key, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final proposal = session.proposal;
    final colors = context.colors;
    final t = context.textStyles;
    // El mismo `proposalStateStyle` que usa la burbuja del chat. Antes esta
    // pantalla señalaba "espera tu respuesta" con un borde verde y el chat
    // con fondo lima: el mismo estado, dos idiomas.
    final style = proposalStateStyle(context, proposal, short: true);
    final relative = relativeDay(proposal.scheduledAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      // Sólo se tiñe lo que **te pide algo**. Aquí las secciones ya agrupan
      // por estado, así que pintar también las que esperan a la otra persona
      // sería repetir con color lo que ya dice el título — y de paso gastar
      // el color más llamativo de la app en algo que no requiere nada.
      color: style.wantsAttention ? style.background : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(when: proposal.scheduledAt),
              const SizedBox(width: 14),
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
                        Text(
                          formatTime(proposal.scheduledAt),
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (relative != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            relative,
                            style: t.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MiniAvatar(url: session.otherPhoto),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            session.otherDisplayName,
                            style: t.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            // Se dice también cuando falta: un hueco en
                            // blanco parece que el sitio está puesto y no se
                            // ve, y aquí "sin sitio" es información — queda
                            // algo por acordar.
                            proposal.placeName ?? S.current.noSpecificPlace,
                            style: t.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (style.wantsAttention) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(style.icon, size: 15, color: style.foreground),
                          const SizedBox(width: 5),
                          Text(
                            style.headline,
                            style: t.labelMedium?.copyWith(
                              color: style.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La hoja de calendario: día, mes y día de la semana.
///
/// Es la pieza que cambia de qué va la pantalla. Con números tabulares para
/// que las tarjetas no bailen entre un día de una cifra y otro de dos.
class _DateBlock extends StatelessWidget {
  final DateTime when;

  const _DateBlock({required this.when});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = context.textStyles;
    final d = dateBlock(when);

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            d.month,
            style: t.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            d.day,
            style: t.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            d.weekday,
            style: t.labelSmall?.copyWith(color: colors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

/// La cara, en pequeño. Sigue sirviendo para reconocer a alguien de un
/// vistazo, pero ya no es el titular de la fila.
class _MiniAvatar extends StatelessWidget {
  final String? url;

  const _MiniAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 22,
        height: 22,
        child: url == null
            ? Container(
                color: colors.surfaceContainerHighest,
                child: Icon(
                  Icons.person_outline,
                  size: 14,
                  color: colors.outline,
                ),
              )
            : NetworkPhoto(url: url!, fit: BoxFit.cover, iconSize: 14),
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

  /// El nivel que la otra persona declara hoy en este deporte. Es contra lo
  /// que se le pregunta a quien valora ("¿era intermedio?"), así que sin él
  /// esa pregunta no se puede hacer y se esconde.
  final SkillLevel? theirLevel;

  final Future<void> Function({
    required bool played,
    String? outcome,
    bool? wouldRepeat,
    SkillLevel? assessedLevel,
    bool skipped,
  })
  onAnswer;

  const _ConfirmCard({
    super.key,
    required this.session,
    required this.onAnswer,
    this.theirLevel,
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

  /// Lo que ha contestado a "¿tenía ese nivel?". `null` mientras no diga
  /// nada, y contestar que no abre la lista para que elija el de verdad.
  SkillLevel? _assessedLevel;
  bool _levelDisagrees = false;

  bool get _isTennis => widget.session.proposal.sport == Sport.tennis;

  Future<void> _send({required bool played}) async {
    setState(() => _busy = true);
    try {
      await widget.onAnswer(
        played: played,
        outcome: played ? _outcome : null,
        wouldRepeat: null,
        assessedLevel: played ? _assessedLevel : null,
        skipped: false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saltarse la reseña.
  ///
  /// Tiene que existir. Sin salida, quien no quiere contestar tiene dos
  /// opciones —mentir o dejar la tarjeta ahí para siempre— y las dos son
  /// peores que un "ahora no": la primera envenena el dato que sostiene los
  /// niveles de todo el mundo, y la segunda convierte la pestaña en una lista
  /// de deberes que no baja nunca.
  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      await widget.onAnswer(played: false, skipped: true);
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
                    S.current.sessionWith(noun, s.otherDisplayName),
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
              Text(S.current.didYouPlay, style: context.textStyles.bodyLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => setState(() => _played = true),
                      child: Text(S.current.yesWePlayed),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _send(played: false),
                      child: Text(S.current.itCouldNotBe),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // La salida. Discreta y en texto, no compitiendo con las dos de
              // arriba: está para quien la necesita, no para invitar a usarla.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(S.current.skip),
                ),
              ),
            ] else ...[
              if (_isTennis) ...[
                Text(
                  S.current.howDidItEnd,
                  style: context.textStyles.bodyLarge,
                ),
                const SizedBox(height: 8),
                // Sin "Empate": en tenis no existe. Estaba ahí de cuando esta
                // pantalla servía también para correr.
                // "Yo" y el nombre del rival, en vez de "Gané"/"Perdí": la
                // pregunta es quién ganó, y contestarla con un nombre se lee
                // solo. "Perdí" obliga a traducir mentalmente la respuesta.
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in [
                      ('WON', S.current.meWon),
                      ('LOST', s.otherDisplayName),
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

              ..._levelQuestion(context, s.otherDisplayName),

              // Fuera la pregunta de "¿repetirías?": no la contestaba nadie
              // con criterio y no la leía nada — el dato que de verdad dice si
              // repetirías es que vuelvas a proponerle jugar.
              //
              // Al quitarla hace falta un botón propio: antes eran sus dos
              // botones los que enviaban la respuesta entera.
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _send(played: true),
                  child: Text(S.current.save),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "¿Era de verdad intermedio?"
  ///
  /// Es la única pregunta de la app cuya respuesta **no la escribe el dueño
  /// del perfil**. Todo lo demás que se enseña de alguien —su nivel, sus
  /// años jugando, su club— lo ha puesto esa misma persona; esto lo dice
  /// quien acaba de jugar contra ella, que es la única fuente que puede
  /// corregirlo.
  ///
  /// Se pregunta en dos pasos y no con una lista de cuatro niveles a pelo:
  /// la respuesta normal es "sí", y con la lista abierta hay que leer y
  /// elegir siempre. Un sí/no se contesta sin pensar, y sólo quien discrepa
  /// paga el segundo paso.
  List<Widget> _levelQuestion(BuildContext context, String name) {
    final theirs = widget.theirLevel;
    // Sin nivel declarado no hay nada que confirmar ni que corregir.
    if (theirs == null) return const [];

    return [
      Text(
        S.current.wouldYouSayPlaysAt(name, theirs.label.toLowerCase()),
        style: context.textStyles.bodyLarge,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              // Decir que sí es guardar **su** nivel: "correcto" no es otra
              // cosa que estar de acuerdo con lo que pone.
              onPressed: () => setState(() {
                _assessedLevel = theirs;
                _levelDisagrees = false;
              }),
              style: _assessedLevel == theirs && !_levelDisagrees
                  ? OutlinedButton.styleFrom(
                      backgroundColor: context.colors.primaryContainer,
                    )
                  : null,
              child: Text(S.current.yes),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _levelDisagrees = true;
                _assessedLevel = null;
              }),
              style: _levelDisagrees
                  ? OutlinedButton.styleFrom(
                      backgroundColor: context.colors.tertiaryContainer,
                    )
                  : null,
              child: Text(S.current.no),
            ),
          ),
        ],
      ),
      if (_levelDisagrees) ...[
        const SizedBox(height: 10),
        Text(
          S.current.whichWouldYouSay,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final level in SkillLevel.values)
              if (level != theirs)
                ChoiceChip(
                  label: Text(level.label),
                  selected: _assessedLevel == level,
                  onSelected: (_) => setState(() => _assessedLevel = level),
                ),
          ],
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  String _whenLabel(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return S.current.today;
    if (days == 1) return S.current.yesterday;
    return S.current.daysAgo(days);
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

    // La fila entera abre la ficha de esa persona. Era el único sitio de la
    // app donde salía alguien y no se podía llegar a su perfil: en Descubrir,
    // en el chat y en Compañeros sí, y aquí —donde estás mirando con quién
    // has jugado— no. Toda la fila y no sólo el nombre, porque un objetivo de
    // 24 dp de alto dentro de una lista se falla más de lo que se acierta.
    return InkWell(
      onTap: () => context.pushNamed(
        AppRoutes.userProfileName,
        pathParameters: {'userId': session.otherUserId},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Misma lógica que arriba, en pequeño: la fecha manda también aquí,
            // porque lo que ordena un historial es cuándo pasó. Sin fondo, que
            // esto es para mirar y no debe competir con lo que sí pide algo.
            SizedBox(
              width: 52,
              child: Text(
                formatPastDate(session.proposal.scheduledAt),
                style: t.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _MiniAvatar(url: photo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.otherDisplayName,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (label != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
                S.current.itWasNotPlayed,
                style: t.labelMedium?.copyWith(color: colors.onSurfaceVariant),
              )
            else if (!session.skipped)
              // Ni contestado ni sabido: se dice, en vez de dejar el hueco.
              //
              // Saltado **no** entra aquí, y es lo que arregla el fallo: al
              // saltar se guarda `played = false` porque la columna no admite
              // nulos, y la fila salía marcada "No se jugó" — una afirmación
              // que quien saltó nunca hizo, y justo la que `skipped` existe
              // para no tener que hacer. Tampoco vale "Sin contestar": eso
              // dice que la app sigue esperando, y ya no espera. No afirmar
              // nada se pinta no escribiendo nada.
              Text(
                S.current.unanswered,
                style: t.labelMedium?.copyWith(color: colors.outline),
              ),
          ],
        ),
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
