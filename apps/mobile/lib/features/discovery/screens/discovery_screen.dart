import 'package:flutter/material.dart';
import 'package:match_point/core/analytics/analytics.dart';
import 'package:match_point/core/theme/app_theme.dart';
import 'package:match_point/core/ui/widgets/error_state_view.dart';
import 'package:match_point/core/ui/widgets/screen_header.dart';
import 'package:match_point/core/utils/app_sports.dart';
import 'package:match_point/core/utils/invite.dart';

import '../../../core/network/api.dart';
import '../../../core/storage/local_flags.dart';
import '../../onboarding/models/profile.dart';
import '../../onboarding/services/profile_service.dart';
import '../discovery_controller.dart';
import '../models/discover_filters.dart';
import '../models/discover_profile.dart';
import '../models/skill_level.dart';
import '../models/sport.dart';
import '../services/discovery_service.dart';
import 'package:match_point/features/discovery/models/swipe_type.dart';
import '../../../core/ui/widgets/discovery/discovery_intro_banner.dart';
import '../../../core/ui/widgets/discovery/discovery_match_dialog.dart';
import '../../../core/ui/widgets/discovery/discovery_preferences_sheet.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/ui/widgets/discovery/player_list_tile.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Buscar con quién jugar.
///
/// **Esta pantalla dejó de ser un mazo de caras.** Lo era: hasta tres
/// tarjetas apaisadas que se arrastraban a un lado o al otro, heredado
/// directamente de cómo funciona una app de citas. El problema no era el
/// gesto, era el orden de las preguntas — decidías por la foto y sólo
/// después descubrías, tres mensajes más tarde, que esa persona no puede
/// jugar ningún día que tú puedas.
///
/// Ahora arranca por la pregunta que de verdad decide si dos personas acaban
/// en una pista: **cuándo puede jugar cada una**. Encima van los filtros, y
/// debajo una lista donde cada fila dice, antes que nada, en qué franjas
/// coincidís (ver `PlayerListTile`).
///
/// El mazo llegó a convivir con la lista detrás de un botón de la cabecera,
/// y se quitó: dos formas de hacer lo mismo obligan a mantener las dos y a
/// que cada mejora de una se replique en la otra, a cambio de un modo que
/// era más divertido y peor para decidir.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  DiscoveryController? controller;
  bool _showIntro = false;

  /// Guardadas para poder abrir la hoja de filtros ya rellena sin volver a
  /// pedir `/me`, y para saber qué deportes pedirle al backend.
  Preferences? _preferences;
  List<Sport> _mySports = const [];

  /// Mi propio nivel, para que las filas puedan decir "tu mismo nivel" en
  /// vez de repetir la etiqueta suelta del otro.
  SkillLevel? _myLevel;

  /// Mi propia foto, para que el cuadro de "ahora sois compañeros" enseñe
  /// las dos caras y no sólo la del otro.
  String? _myPhoto;

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
  /// `/me` antes de poder crear el controller. Si `/me` falla, el controller
  /// cae a los deportes que la app ofrece hoy en vez de dejar la pantalla
  /// rota.
  Future<void> _init({DiscoverFilters? keepFilters}) async {
    List<Sport> mySports = const [];
    Preferences? prefs;
    SkillLevel? myLevel;
    String? myPhoto;
    try {
      final me = await ProfileService(Api.client).getMe();
      mySports = me.profile?.sports ?? const [];
      final photos = me.profile?.photos ?? const <String>[];
      myPhoto = photos.isEmpty ? null : photos.first;
      prefs = me.preferences;
      final sport = singleSport;
      if (sport != null) myLevel = me.skillLevels[sport];
    } catch (_) {
      // sigue con lo que haya -> el controller cae a los deportes activos
    }

    if (!mounted) return;
    final created = DiscoveryController(
      DiscoveryService(Api.client),
      sports: _sportsToFetch(prefs, mySports),
      filters: keepFilters ?? controller?.filters ?? DiscoverFilters.none,
    );
    setState(() {
      _preferences = prefs;
      _mySports = mySports;
      _myLevel = myLevel;
      _myPhoto = myPhoto;
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
  ///
  /// `onlyEnabled` (en el controller) recorta además a los deportes que la
  /// app ofrece hoy — hay cuentas de cuando se podía elegir correr.
  static List<Sport> _sportsToFetch(Preferences? prefs, List<Sport> mySports) {
    final wanted = prefs?.sportsWanted ?? const <Sport>[];
    if (wanted.isEmpty) return mySports;
    final shared = wanted.where(mySports.contains).toList();
    return shared.isEmpty ? mySports : shared;
  }

  /// Abre los ajustes de a quién ver (edad, radio, género) y, si se
  /// guardaron, vuelve a montar el feed desde cero — cambian los candidatos,
  /// así que quedarse con la lista anterior mostraría gente ya filtrada.
  Future<void> _openPreferences() async {
    final before = controller?.filters ?? DiscoverFilters.none;
    final result = await showDiscoveryPreferencesSheet(
      context,
      current: _preferences,
      mySports: _mySports,
      filters: before,
    );
    if (!mounted) return;

    final filtersChanged =
        result.filters.when.mask != before.when.mask ||
        result.filters.level != before.level;
    if (filtersChanged) {
      Analytics.filterChanged(
        byTime: result.filters.when.isNotEmpty,
        byLevel: result.filters.level != null,
      );
    }
    // Nada que hacer si se cerro sin tocar: recargar el feed por abrir y
    // cerrar una hoja pierde el sitio en la lista sin motivo.
    if (!result.saved && !filtersChanged) return;

    // `_init` reconstruye el controller, asi que los filtros nuevos hay que
    // pasarselos por aqui o se perderian al recargar.
    await _init(keepFilters: result.filters);
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

      if (type == SwipeType.like) {
        Analytics.playerLiked(instantMatch: res.matched);
        if (res.matched) Analytics.matchCreated();
      } else {
        Analytics.playerPassed();
      }

      if (type == SwipeType.like && res.matched) {
        await showDiscoveryMatchDialog(
          context,
          user: res.user,
          matchId: res.matchId,
          myPhoto: _myPhoto,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.current.couldNotRegisterDecision)),
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
                // Titulo grande y solo. Aqui vivian ademas un subtitulo con
                // el recuento ("7 personas juegan al tenis cerca de ti") y una
                // barra con dos chips de filtro: entre las tres cosas, la
                // pantalla empezaba con cuatro lineas de interfaz antes de la
                // primera persona, y se leia como un panel de control. El
                // recuento no cambiaba ninguna decision —la lista ya esta
                // debajo, y se ve— y los filtros se han movido dentro de la
                // hoja, a un toque del icono.
                // El mismo `ScreenHeader` que Compañeros y Partidos. Esta
                // pantalla tenía su propia copia —de aquí salió el widget—
                // y dejarla suelta era garantizar que las tres se volvieran
                // a separar en cuanto alguna cambiara.
                ScreenHeader(
                  title: S.current.findYourMatch,
                  actions: [
                    _FilterButton(
                      active: controller.filters.activeCount,
                      onTap: _openPreferences,
                    ),
                  ],
                ),

                if (_showIntro) DiscoveryIntroBanner(onDismiss: _dismissIntro),

                Expanded(child: _buildBody(context, controller)),
              ],
            ),
          ),
        );
      },
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
      Analytics.discoverEmpty(filtered: controller.filters.isNotEmpty);
      return _EmptyState(
        filters: controller.filters,
        onClearFilters: () => controller.setFilters(DiscoverFilters.none),
        onOpenPreferences: _openPreferences,
      );
    }

    Analytics.discoverLoaded(
      count: controller.stack.length,
      filtered: controller.filters.isNotEmpty,
    );
    return _buildList(context, controller);
  }

  /// El **mismo** perfil que se abre desde el chat, y por la misma ruta.
  ///
  /// Antes esto abría una hoja modal propia (`DiscoveryPreviewSheet`) que
  /// enseñaba una versión recortada del perfil: foto, nivel y poco más. El
  /// problema no era que fuese modal, era que había **dos** pantallas para
  /// una cosa — y como pasa siempre, se les fue quedando distinto lo que
  /// enseñaba cada una (la hoja nunca supo del horario compartido ni del
  /// historial de partidos). Con una sola, cualquier campo nuevo del perfil
  /// aparece en los dos sitios sin acordarse de nada.
  void _openProfile(DiscoverProfile user) {
    context.pushNamed(
      AppRoutes.userProfileName,
      pathParameters: {'userId': user.userId},
    );
  }

  Widget _buildList(BuildContext context, DiscoveryController controller) {
    final people = controller.stack;
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final user = people[index];
          return PlayerListTile(
            key: ValueKey(user.userId),
            user: user,
            myLevel: _myLevel,
            onTap: () => _openProfile(user),
            onWantToPlay: () => _handleSwipe(user, SwipeType.like),
            onDismiss: () => _handleSwipe(user, SwipeType.pass),
          );
        },
      ),
    );
  }
}

/// El final del feed, que hasta ahora era un callejón sin salida.
///
/// Decía "vuelve más tarde, se suman perfiles nuevos todo el tiempo" y no
/// ofrecía nada que hacer — a propósito, porque volver a pedir el mismo feed
/// no traía nada nuevo. Pero con filtros sí hay algo que hacer, y casi
/// siempre es lo correcto: el motivo más probable de una lista vacía no es
/// que no haya nadie, es que el "cuándo" o el radio están demasiado
/// apretados.
class _EmptyState extends StatelessWidget {
  final DiscoverFilters filters;
  final VoidCallback onClearFilters;
  final VoidCallback onOpenPreferences;

  const _EmptyState({
    required this.filters,
    required this.onClearFilters,
    required this.onOpenPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final colors = context.colors;
    final filtered = filters.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: colors.outline),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'Nadie libre en esas franjas'
                  : S.current.nobodyNearbyYet,
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? S.current.tryMoreFreeSlots
                  : S.current.widenTheRadius,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (filtered)
              FilledButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(S.current.clearFilters),
              )
            else
              FilledButton.icon(
                onPressed: onOpenPreferences,
                icon: const Icon(Icons.travel_explore),
                label: Text(S.current.widenRadius),
              ),
            const SizedBox(height: 4),
            // La otra salida, y en una app de densidad local la de verdad:
            // si no hay nadie por tu zona, ampliar el radio te enseña gente
            // que te pilla lejos — traer a alguien que ya conoces te
            // resuelve el problema.
            Builder(
              builder: (context) => TextButton.icon(
                onPressed: () => Invite.share(context),
                icon: const Icon(Icons.person_add_alt),
                label: Text(S.current.inviteSomeoneYouPlayWith),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El acceso a los filtros, con una chapa que dice cuantos hay puestos.
///
/// La chapa no es decorativa: al sacar los filtros de la pantalla principal,
/// sin ella no habria forma de saber que la lista esta recortada, y una lista
/// corta se leeria como "no hay nadie" en vez de "estas filtrando".
class _FilterButton extends StatelessWidget {
  final int active;
  final VoidCallback onTap;

  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: S.current.filters,
          icon: Icon(
            Icons.tune,
            color: active > 0 ? colors.primary : colors.onSurface,
          ),
        ),
        if (active > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$active',
                style: context.textStyles.labelSmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
