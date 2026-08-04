import 'package:flutter/material.dart';

import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/utils/date_format_es.dart';

import '../models/proposal.dart';
import '../services/proposal_service.dart';
import 'session_detail_screen.dart';
import '../../discovery/models/sport.dart';

/// "Que juego proximamente" — lo que convierte MatchPoint de "he hecho
/// match con alguien" a "tengo un partido el jueves".
///
/// Solo propuestas ACEPTADAS y que no hayan pasado (el backend ya filtra
/// las dos cosas, con unas horas de gracia para que una sesion no
/// desaparezca justo cuando empieza).
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

  /// Abre la ficha del partido, no el chat: tocar una sesion para acabar
  /// en una conversacion donde hay que reconstruir cuando y donde era
  /// tenia poco sentido. Desde la ficha se puede saltar al chat.
  Future<void> _openDetail(UpcomingSession session) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(session: session),
      ),
    );
    // Puede haberse cancelado desde dentro.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Próximos partidos')),
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
      // funcionando con la lista vacia.
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
              'Cuando tú y un match acordéis día y hora, el partido '
              'aparecerá aquí.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _sessionTile(context, _sessions[i]),
    );
  }

  Widget _sessionTile(BuildContext context, UpcomingSession session) {
    final proposal = session.proposal;
    final photo = session.otherPhoto;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null ? const Icon(Icons.person) : null,
      ),
      title: Row(
        children: [
          Icon(
            proposal.sport == Sport.tennis
                ? Icons.sports_tennis
                : Icons.directions_run,
            size: 16,
            color: context.colors.primary,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                color: context.colors.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openDetail(session),
    );
  }
}
