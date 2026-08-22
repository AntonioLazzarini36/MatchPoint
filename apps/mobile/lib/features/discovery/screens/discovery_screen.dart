import 'package:flutter/material.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/ui/widgets/error_state_view.dart';

import '../../../core/network/api.dart';
import '../../../core/storage/local_flags.dart';
import '../../onboarding/models/profile.dart';
import '../../onboarding/services/profile_service.dart';
import '../discovery_controller.dart';
import '../models/discover_profile.dart';
import '../models/sport.dart';
import '../services/discovery_service.dart';
import 'package:match_point/features/discovery/models/swipe_type.dart';
import '../../../core/ui/widgets/discovery/discovery_intro_banner.dart';
import '../../../core/ui/widgets/discovery/discovery_match_dialog.dart';
import '../../../core/ui/widgets/discovery/discovery_preferences_sheet.dart';
import '../../../core/ui/widgets/discovery/discovery_mini_card.dart';
import '../../../core/ui/widgets/discovery/discovery_preview_sheet.dart';

/// Columna de tarjetas apaisadas, en vez del mazo de una en una a pantalla
/// completa. Cada tarjeta se arrastra por separado — a un lado para
/// jugar, al otro para pasar — y al tocarla se abre el preview. Sin
/// botones de like/pass: el gesto *es* la acción, un botón sobraría.
///
/// Tres tarjetas, no cuatro, y **escalonadas** (cada una desplazada al lado
/// contrario de la anterior): con cuatro no cabía información util en
/// ninguna, y alineadas al milímetro la pantalla parecía una tabla. El
/// desplazamiento también deja claro que se arrastran a los lados.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  static const _maxVisible = 3;
  static const _cardSpacing = 12.0;

  /// Cuánto se desplaza cada tarjeta respecto al centro. Suficiente para
  /// que se lea como un zigzag, no tanto como para desperdiciar ancho.
  static const _stagger = 18.0;

  DiscoveryController? controller;
  bool _showIntro = false;

  /// Guardadas para poder abrir la hoja de filtros ya rellena sin volver a
  /// pedir `/me`, y para saber qué deportes pedirle al backend.
  Preferences? _preferences;
  List<Sport> _mySports = const [];

  @override
  void initState() {
    super.initState();
    _init();
    _loadIntroFlag();
  }

  Future<void> _loadIntroFlag() async {
    final seen = await LocalFlags.hasSeenDiscoveryIntro();
    if (!mounted || seen) return;
    setState(() => _showIntro = true);
  }

  Future<void> _dismissIntro() async {
    setState(() => _showIntro = false);
    await LocalFlags.setSeenDiscoveryIntro();
  }

  /// El feed depende de las preferencias del usuario, así que hay que leer
  /// `/me` antes de poder crear el controller. Qué deportes se piden sale
  /// de `Preferences.sportsWanted` (lo que quiere ver); si nunca lo ha
  /// tocado, se usan sus propios `Profile.sports` como valor por defecto —
  /// ya los eligió en el onboarding. Si `/me` falla, el controller cae a
  /// tenis (mismo fallback de siempre) en vez de dejar la pantalla rota.
  Future<void> _init() async {
    List<Sport> mySports = const [];
    Preferences? prefs;
    try {
      final me = await ProfileService(Api.client).getMe();
      mySports = me.profile?.sports ?? const [];
      prefs = me.preferences;
    } catch (_) {
      // sigue con lo que haya -> el controller cae a [Sport.tennis]
    }

    if (!mounted) return;
    final created = DiscoveryController(
      DiscoveryService(Api.client),
      sports: _sportsToFetch(prefs, mySports),
    );
    setState(() {
      _preferences = prefs;
      _mySports = mySports;
      controller = created;
    });
    await created.init();
  }

  /// Qué deportes pedirle al backend.
  ///
  /// Siempre **dentro de los tuyos**: `sportsWanted` puede acotar (sólo
  /// quiero ver tenis aunque juegue a los dos) pero no ampliar. Sin este
  /// cruce, alguien que sólo juega al tenis podía pedir corredores, darles
  /// like y acabar en un match que no puede terminar en ninguna quedada:
  /// proponer exige que ambos practiquen ese deporte.
  static List<Sport> _sportsToFetch(Preferences? prefs, List<Sport> mySports) {
    final wanted = prefs?.sportsWanted ?? const <Sport>[];
    if (wanted.isEmpty) return mySports;
    final shared = wanted.where(mySports.contains).toList();
    return shared.isEmpty ? mySports : shared;
  }

  /// Abre los filtros y, si se guardaron, vuelve a montar el feed desde
  /// cero — cambiar edad/deportes/género cambia quién es candidato, así
  /// que quedarse con el stack anterior mostraría gente ya filtrada.
  Future<void> _openFilters() async {
    final saved = await showDiscoveryPreferencesSheet(
      context,
      current: _preferences,
      mySports: _mySports,
    );
    if (!saved || !mounted) return;
    await _init();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _handleSwipe(DiscoverProfile user, SwipeType type) async {
    try {
      final res = await controller!.swipeUser(user: user, type: type);

      if (!mounted) return;

      if (type == SwipeType.like && res.matched) {
        await showDiscoveryMatchDialog(
          context,
          user: res.user,
          matchId: res.matchId,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el swipe, reintenta')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top bar: solo el título y el acceso a filtros — sin
                // selector de deporte ni el toggle "Partner"/"Match" que no
                // hacía nada. Qué deportes se piden sale de los filtros,
                // no de un control aparte aquí arriba.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Descubrir',
                              style: context.textStyles.headlineSmall,
                            ),
                            Text(
                              _subtitle(controller),
                              style: context.textStyles.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _openFilters,
                        tooltip: 'Filtros',
                        icon: Icon(Icons.tune, color: context.colors.onSurface),
                      ),
                    ],
                  ),
                ),

                if (_showIntro) DiscoveryIntroBanner(onDismiss: _dismissIntro),

                Expanded(child: _buildBody(context, controller)),

                // La pista del gesto vive aqui abajo y no dentro de una
                // tarjeta: es una instruccion de la pantalla, no de una
                // persona concreta, y de paso ocupa el hueco que dejaban
                // las tarjetas escalonadas.
                if (controller.stack.isNotEmpty) _swipeHint(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dice de que va la pantalla con datos reales en vez de una frase
  /// generica: cuanta gente queda por mirar y en que deporte.
  String _subtitle(DiscoveryController controller) {
    final sports = controller.sports;
    final deporte = sports.length == 1 ? sports.first.label.toLowerCase() : null;
    final count = controller.stack.length;
    if (count == 0) return deporte == null ? 'Sin perfiles' : 'Sin perfiles de $deporte';
    final gente = count == 1 ? '1 perfil' : '$count perfiles';
    return deporte == null ? '$gente cerca de ti' : '$gente de $deporte cerca de ti';
  }

  Widget _swipeHint(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.west, size: 14, color: colors.error),
          const SizedBox(width: 6),
          Text(
            'Pasar',
            style: context.textStyles.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Text(
            '   ·   ',
            style: context.textStyles.labelSmall?.copyWith(
              color: colors.outline,
            ),
          ),
          Text(
            'Quiero jugar',
            style: context.textStyles.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.east, size: 14, color: colors.primary),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, DiscoveryController controller) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return ErrorStateView(
        error: controller.error!,
        onRetry: () async => controller.reload(),
      );
    }

    if (controller.stack.isEmpty) {
      // Sin botón de "reintentar": el feed ya excluye a quien swipeaste,
      // así que volver a pedirlo no trae nada nuevo salvo que aparezca
      // gente de verdad — un botón ahí solo aparentaba tener función.
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: context.colors.outline),
            const SizedBox(height: 16),
            Text(
              'Por ahora no hay más perfiles cerca',
              style: context.textStyles.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vuelve más tarde, se suman perfiles nuevos todo el tiempo',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final stack = controller.stack;
    final visible = stack.length <= _maxVisible
        ? stack
        : stack.sublist(stack.length - _maxVisible);

    // Alto fijo por tarjeta ("un tercio del hueco disponible") aunque
    // queden menos: así una tarjeta no crece de golpe sólo porque se haya
    // vaciado el mazo. Lo único que cambia al swipear es cuántas filas
    // hay, no el tamaño de cada una.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight =
              (constraints.maxHeight - _cardSpacing * (_maxVisible - 1)) /
              _maxVisible;
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: _cardSpacing),
                Padding(
                  // Zigzag: pares desplazados a la derecha, impares a la
                  // izquierda.
                  padding: i.isEven
                      ? const EdgeInsets.only(left: _stagger)
                      : const EdgeInsets.only(right: _stagger),
                  child: SizedBox(
                    height: cardHeight,
                    child: _buildCard(context, controller, visible[i]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    DiscoveryController controller,
    DiscoverProfile user,
  ) {
    return Dismissible(
      // Includes `generation` so a card rolled back after a failed swipe
      // gets a fresh key instead of resurrecting the Dismissible that was
      // just dismissed — reusing that key crashes.
      key: ValueKey('${user.userId}_${controller.generation}'),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        final type = direction == DismissDirection.startToEnd
            ? SwipeType.like
            : SwipeType.pass;
        _handleSwipe(user, type);
      },
      background: _swipeOverlay(
        context,
        Alignment.centerLeft,
        Icons.handshake,
        context.colors.primary,
      ),
      secondaryBackground: _swipeOverlay(
        context,
        Alignment.centerRight,
        Icons.close,
        context.colors.error,
      ),
      child: DiscoveryMiniCard(
        user: user,
        onTap: () => showDiscoveryPreviewSheet(context, user),
      ),
    );
  }

  /// "Difuminado" directional hint shown as the card is dragged — a
  /// translucent color wash across the whole card rather than a small
  /// badge, since these cards are too small for a badge to read clearly.
  Widget _swipeOverlay(
    BuildContext context,
    Alignment alignment,
    IconData icon,
    Color color,
  ) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
