import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../network/api.dart';
import '../../../../features/discovery/models/discover_profile.dart';
import '../../../../features/matches/services/matches_service.dart';
import '../../profile/network_photo.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// El momento en que dos personas conectan.
///
/// Era el trozo más antiguo de la app y se notaba: un cuadro enorme con un
/// icono de 80 px, un titular gigante y una frase debajo explicando lo que ya
/// decía el titular ("ya podéis hablar y organizar una quedada"). Ocupaba
/// media pantalla para dar una noticia de cuatro palabras.
///
/// Ahora es una tarjeta pequeña con las **dos caras**, que es la información
/// que de verdad importa aquí — con quién has conectado — y dos botones. Sin
/// frase explicativa: el titular y los botones ya dicen todo lo que hay que
/// saber, y un texto que repite el botón que tiene debajo sólo retrasa el
/// toque.
///
/// La animación es corta y sirve para algo: las dos fotos entran desde los
/// lados y se juntan. Es la idea entera del momento, contada sin palabras y en
/// medio segundo.
Future<void> showDiscoveryMatchDialog(
  BuildContext context, {
  required DiscoverProfile user,
  required String? matchId,
  String? myPhoto,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: _MatchCard(user: user, matchId: matchId, myPhoto: myPhoto),
    ),
  );
}

class _MatchCard extends StatefulWidget {
  const _MatchCard({
    required this.user,
    required this.matchId,
    required this.myPhoto,
  });

  final DiscoverProfile user;
  final String? matchId;
  final String? myPhoto;

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool _opening = false;

  /// Abre el chat de ese match.
  ///
  /// **El orden importa y es la parte fácil de romper.** Cerrar el diálogo
  /// destruye este widget, así que cualquier `context` o `mounted` de después
  /// ya no vale: la navegación se quedaba sin hacer y el botón parecía muerto.
  ///
  /// Por eso el router y el resto se cogen **antes** de nada, se busca el
  /// match, y sólo al final se cierra y se navega — con objetos que sobreviven
  /// a este widget.
  Future<void> _openChat() async {
    final id = widget.matchId;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Sin id no hay chat que abrir; al menos que el botón cierre, en vez de
    // no hacer nada.
    if (id == null) {
      navigator.pop();
      return;
    }

    setState(() => _opening = true);
    try {
      // El chat necesita el MatchItem completo (perfiles, deporte…), no sólo
      // el id — se busca en /matches, igual que hace MatchesScreen.
      final matches = await MatchesService(Api.client).fetchMatches();
      final match = matches.firstWhere((m) => m.matchId == id);
      navigator.pop();
      router.push('/chat/${match.matchId}', extra: match);
    } catch (_) {
      if (mounted) setState(() => _opening = false);
      messenger.showSnackBar(
        SnackBar(content: Text(S.current.couldNotOpenChatTryMatches)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _slidingFace(from: -1, photo: widget.myPhoto, offset: -26),
                _slidingFace(
                  from: 1,
                  photo: widget.user.mainPhoto,
                  offset: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.current.youAreNowPartners,
            textAlign: TextAlign.center,
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.current.keepLooking),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _opening ? null : _openChat,
                  child: _opening
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(S.current.organizeMatch),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Una cara que entra desde su lado y se para donde le toca.
  ///
  /// `from` es -1 (izquierda) o 1 (derecha); `offset` es dónde acaba, para que
  /// las dos se solapen un poco — juntas, no una al lado de la otra.
  Widget _slidingFace({
    required double from,
    required String? photo,
    required double offset,
  }) {
    final anim = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(offset + from * 60 * (1 - t), 0),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.surface, width: 3),
          color: context.colors.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? Icon(
                Icons.person,
                color: context.colors.outline,
                size: 32,
              )
            : NetworkPhoto(url: photo, fit: BoxFit.cover, iconSize: 32),
      ),
    );
  }
}
