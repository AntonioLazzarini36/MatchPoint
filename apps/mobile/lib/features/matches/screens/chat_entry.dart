import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:match_point/app/routes.dart';
import 'package:match_point/core/network/api.dart';
import 'package:match_point/features/matches/models/match_item.dart';
import 'package:match_point/features/matches/services/matches_service.dart';

import 'chat_screen.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// La puerta de entrada al chat cuando **no** se viene de la lista.
///
/// `ChatScreen` necesita bastante más que un id: quién eres tú, quién es la
/// otra persona, su nombre, su foto y el deporte. Viniendo de "Compañeros" eso
/// ya está cargado y se pasa entero por `extra`, que es lo barato y lo que se
/// sigue haciendo.
///
/// Pero una notificación sólo trae un `matchId` — no puede traer más, cabe
/// muy poco y además llegaría caducado. Sin esta pantalla intermedia, abrir el
/// chat desde un aviso significaba estrellar la app contra el `as MatchItem`
/// del router. Aquí se pide la lista y se busca ese id: una petición de más,
/// sólo en el camino que viene de fuera.
class ChatEntry extends StatefulWidget {
  const ChatEntry({super.key, required this.matchId, this.match});

  final String matchId;

  /// Ya resuelto (se viene de la lista). Si es null, se carga aquí.
  final MatchItem? match;

  @override
  State<ChatEntry> createState() => _ChatEntryState();
}

class _ChatEntryState extends State<ChatEntry> {
  late Future<MatchItem?> _future;

  @override
  void initState() {
    super.initState();
    final known = widget.match;
    _future = known != null ? Future.value(known) : _load();
  }

  Future<MatchItem?> _load() async {
    final all = await MatchesService(Api.client).fetchMatches();
    for (final m in all) {
      if (m.matchId == widget.matchId) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchItem?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final match = snap.data;
        if (match == null) {
          // Puede pasar de verdad: el aviso llegó y para cuando se abre, la
          // otra persona ha deshecho el match. Mejor decirlo que dejar una
          // pantalla en blanco.
          return _Unavailable(
            message: snap.hasError
                ? S.current.couldNotOpenConversation
                : S.current.conversationNoLongerAvailable,
          );
        }

        final photos = match.otherUser.profile?.photos ?? const [];
        return ChatScreen(
          matchId: match.matchId,
          myUserId: match.me.userId,
          otherUserId: match.otherUser.userId,
          otherName: match.otherUser.profile?.displayName ?? S.current.noName,
          otherPhotoUrl: photos.isNotEmpty ? photos.first : null,
          sport: match.sport,
        );
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.shell),
                child: Text(S.current.back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
