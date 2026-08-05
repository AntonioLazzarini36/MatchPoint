import 'package:flutter/material.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/network/notification_counts.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/date_format_es.dart';
import 'package:match_point/core/utils/sport_words.dart';

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
  bool _loading = true;
  String? _error;

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
      final sessions = await _service.listUpcoming();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Abre la ficha de la quedada, no el chat: tocar una sesión para acabar
  /// en una conversación donde hay que reconstruir cuándo y dónde era
  /// tenía poco sentido. Desde la ficha se puede saltar al chat.
  Future<void> _openDetail(UpcomingSession session) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(session: session),
      ),
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
      appBar: AppBar(title: const Text('Quedadas')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.colors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_sessions.isEmpty) {
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
              'Cuando propongas jugar a alguno de tus matches (o te lo '
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
        if (needsAnswer.isNotEmpty)
          ..._section(context, 'Esperan tu respuesta', needsAnswer),
        if (confirmed.isNotEmpty)
          ..._section(context, 'Confirmadas', confirmed),
        if (waiting.isNotEmpty)
          ..._section(context, 'Esperando respuesta', waiting),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<UpcomingSession> sessions,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          '$title (${sessions.length})',
          style: context.textStyles.titleSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
      for (final session in sessions) _sessionTile(context, session),
    ];
  }

  Widget _sessionTile(BuildContext context, UpcomingSession session) {
    final proposal = session.proposal;
    final photo = session.otherPhoto;
    final colors = context.colors;
    final needsAnswer = proposal.isPending && !proposal.mine;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // Un borde de acento sólo en lo que espera respuesta tuya: si todas
      // las tarjetas destacan, no destaca ninguna.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: needsAnswer ? colors.primary : colors.surfaceContainerHighest,
          width: needsAnswer ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openDetail(session),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          sportIcon(proposal.sport),
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            session.otherDisplayName,
                            style: context.textStyles.titleMedium,
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
