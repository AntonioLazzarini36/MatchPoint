import 'package:flutter/material.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/ui/widgets/screen_header.dart';
import 'package:match_point/core/ui/widgets/error_state_view.dart';
import 'package:go_router/go_router.dart';

import '../matches_controller.dart';
import '../models/match_item.dart';
import '../services/matches_service.dart';
import '../../../core/ui/dialogs/confirm_dialog.dart';
import '../../../core/ui/widgets/matches/partner_row.dart';
import '../models/proposal.dart';
import '../services/proposal_service.dart';
import '../../../core/network/connection_error.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late final MatchesController controller;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// El mapa de clubes es exclusivo de tenis, asi que a quien solo corre
  /// no se le enseña: antes aparecia siempre, y desde el chat de un match
  /// de correr llevaba a una pantalla de pistas que no le sirve de nada.
  @override
  void initState() {
    super.initState();
    controller = MatchesController(
      MatchesService(Api.client),
      ProposalService(Api.client),
    );
    controller.init();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  /// Siempre recarga al volver del chat: entrar marca los mensajes como
  /// leídos (best-effort, ver ChatController.init), así que el preview/
  /// unread de la lista queda desactualizado incluso si no hubo unmatch.
  Future<void> _openChat(MatchItem m) async {
    await context.push<bool>('/chat/${m.matchId}', extra: m);
    controller.reload();
  }

  Future<void> _confirmUnmatch(MatchItem m) async {
    final name = m.otherUser.profile?.displayName ?? 'esta persona';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Dejar de ser compañeros',
      content:
          '¿Seguro que quieres dejar de ser compañeros con $name? Se borrará '
          'también la conversación, y no se puede deshacer.',
      confirmLabel: 'Dejar de ser compañeros',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await controller.service.unmatch(m.matchId);
      controller.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              e,
              fallback: 'No se ha podido completar la operación.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return Scaffold(
          // Sin `AppBar`: la misma cabecera que Descubrir y Partidos (ver
          // `ScreenHeader`). El acceso al mapa de clubes vivia aqui arriba,
          // pero se solapaba con el boton de proponer del chat (que ademas
          // lleva el club ya elegido); sigue accesible desde el chat.
          body: SafeArea(
            child: Column(
              children: [
                ScreenHeader(
                  title: 'Tus compañeros',
                  replacement: _searching
                      ? TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: context.textStyles.titleLarge,
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nombre...',
                            border: InputBorder.none,
                          ),
                        )
                      : null,
                  actions: [
                    IconButton(
                      icon: Icon(_searching ? Icons.close : Icons.search),
                      onPressed: _toggleSearch,
                    ),
                  ],
                ),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return ErrorStateView(
        error: controller.error!,
        onRetry: () async => controller.reload(),
      );
    }

    final matches = controller.matches;

    if (matches.isEmpty) {
      // Misma composición que el vacío de Partidos (icono + título + una
      // frase que dice qué hacer): era un `Text` centrado a secas, y puestas
      // las dos pantallas una al lado de la otra se notaba que a esta no la
      // había mirado nadie. El mensaje es el que ya había.
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.groups_outlined,
            size: 64,
            color: context.colors.outline,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Todavía no tienes compañeros',
              style: context.textStyles.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Cuando alguien a quien has dado "Quiero jugar" te lo devuelva, '
              'aparecerá aquí y podréis hablar.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    // El buscador filtra la lista entera. Ya no hay una fila de "nuevos
    // matches" aparte que quedara fuera del filtro.
    final filteredMatches = _query.isEmpty
        ? matches
        : matches
              .where(
                (m) => (m.otherUser.profile?.displayName ?? '')
                    .toLowerCase()
                    .contains(_query),
              )
              .toList();

    if (filteredMatches.isEmpty && _query.isNotEmpty) {
      return Center(
        child: Text(
          'Sin resultados para "$_query"',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    // Agrupado por lo que hay que hacer, no por hora del ultimo mensaje.
    // Ordenar por recencia es lo correcto en una bandeja de chat; aqui lo
    // que caduca es una propuesta sin contestar, no una conversacion.
    final conQuedada = <MatchItem>[];
    final esperanRespuesta = <MatchItem>[];
    final sinPlanes = <MatchItem>[];

    for (final m in filteredMatches) {
      final session = controller.sessionFor(m.matchId);
      if (session == null) {
        sinPlanes.add(m);
      } else if (session.status == ProposalStatus.accepted) {
        conQuedada.add(m);
      } else if (session.isPending && !session.mine) {
        esperanRespuesta.add(m);
      } else {
        // Pendiente pero la propuse yo: no hay nada que hacer con ella
        // todavia, asi que no reclama atencion.
        sinPlanes.add(m);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ..._group(context, 'Esperan tu respuesta', esperanRespuesta),
        ..._group(context, 'Con quedada', conQuedada),
        ..._group(context, 'Sin planes todavía', sinPlanes),
      ],
    );
  }

  List<Widget> _group(BuildContext context, String title, List<MatchItem> ms) {
    if (ms.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
        child: Text(
          '$title · ${ms.length}',
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
      ),
      for (final m in ms)
        PartnerRow(
          match: m,
          session: controller.sessionFor(m.matchId),
          skillLevel: m.otherUser.skillLevels[m.sport],
          onTap: () => _openChat(m),
          onLongPress: () => _confirmUnmatch(m),
        ),
    ];
  }
}
