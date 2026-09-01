import 'package:flutter/material.dart';

import '../../network/notification_counts.dart';
import '../../../features/discovery/screens/discovery_screen.dart';
import '../../../features/matches/screens/matches_screen.dart';
import '../../../features/matches/screens/upcoming_screen.dart';
import '../../../features/profile/screens/profile_screen.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Índices de las pestañas, con nombre.
///
/// Existen porque desde fuera (una notificación) hay que poder decir "abre
/// Partidos" sin escribir un `2` que se rompe en silencio el día que se
/// reordenen.
class ShellTab {
  static const discover = 0;
  static const companions = 1;
  static const upcoming = 2;
  static const profile = 3;
}

class NavigatorShell extends StatefulWidget {
  const NavigatorShell({super.key, this.initialTab = ShellTab.discover});

  /// Pestaña con la que abrir. Sólo se usa al construir el shell.
  final int initialTab;

  /// Petición de cambio de pestaña desde fuera del árbol de widgets.
  ///
  /// Hace falta porque el shell casi nunca se reconstruye: cuando llega una
  /// notificación con la app abierta, ya está montado y `initialTab` pasó hace
  /// rato. Un notificador es la vía más corta para moverlo sin sacar el índice
  /// a un gestor de estado que sólo usaría esto.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  /// Lleva el shell a una pestaña. Si aún no está montado, la petición se
  /// queda guardada y el `initState` la recoge.
  static void goToTab(int tab) => requestedTab.value = tab;

  @override
  State<NavigatorShell> createState() => NavigatorShellState();
}

class NavigatorShellState extends State<NavigatorShell> {
  late int _index = widget.initialTab;

  /// "Partidos" va justo detrás de Compañeros: el recorrido natural es
  /// match -> hablar -> quedar, y tener el plan a un toque es la mitad del
  /// producto ("organizar el partido", no sólo hacer match).
  ///
  /// Se llamó "Quedadas" mientras la app entrelazaba tenis y correr, porque
  /// a quien sólo corre una pestaña de "Partidos" le hablaba de algo que no
  /// hace. Sin running (ver `core/utils/app_sports.dart`) ese paraguas ya no
  /// hace falta, y "partido" es como lo llama todo el mundo.
  final _screens = const [
    DiscoveryScreen(),
    MatchesScreen(),
    UpcomingScreen(),
    ProfileScreen(),
  ];

  final _counts = NotificationCounts.instance;

  @override
  void initState() {
    super.initState();
    _counts.addListener(_onCounts);
    _counts.start();

    NavigatorShell.requestedTab.addListener(_onTabRequested);
    // Una petición que llegó antes de que esto existiera (la app abierta
    // *por* la notificación) se atiende aquí, sin `setState` porque todavía
    // no ha habido un primer build que actualizar.
    final pending = NavigatorShell.requestedTab.value;
    if (pending != null) {
      NavigatorShell.requestedTab.value = null;
      _index = pending;
    }
  }

  @override
  void dispose() {
    _counts.removeListener(_onCounts);
    _counts.stop();
    NavigatorShell.requestedTab.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final tab = NavigatorShell.requestedTab.value;
    if (tab == null || !mounted) return;
    // Se consume: si no, volver al shell más tarde te devolvería otra vez a
    // la pestaña de aquella notificación.
    NavigatorShell.requestedTab.value = null;
    _select(tab);
  }

  void _onCounts() {
    if (mounted) setState(() {});
  }

  /// Al entrar a una pestaña, refresca en cuanto se vuelve a salir de
  /// ella: leer los mensajes o responder una propuesta cambia los
  /// contadores y el badge tiene que bajar sin esperar al siguiente tick.
  void _select(int value) {
    setState(() => _index = value);
    _counts.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_fire_department_outlined),
            selectedIcon: const Icon(Icons.local_fire_department),
            label: S.current.tabDiscover,
          ),
          NavigationDestination(
            icon: _badged(
              const Icon(Icons.chat_bubble_outline),
              _counts.unreadMessages,
            ),
            selectedIcon: _badged(
              const Icon(Icons.chat_bubble),
              _counts.unreadMessages,
            ),
            label: S.current.tabPartners,
          ),
          NavigationDestination(
            // Las dos cosas que reclaman tu atencion en esta pestaña suman en
            // el mismo badge: una propuesta por contestar y una quedada por
            // contar acaban las dos en la misma pantalla, asi que separarlas
            // en dos numeros no le diria nada a nadie.
            icon: _badged(
              const Icon(Icons.event_outlined),
              _counts.pendingProposals + _counts.sessionsToConfirm,
            ),
            selectedIcon: _badged(
              const Icon(Icons.event),
              _counts.pendingProposals + _counts.sessionsToConfirm,
            ),
            label: S.current.tabMatches,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: S.current.tabProfile,
          ),
        ],
      ),
    );
  }

  /// Sin contador no se dibuja nada: un badge vacío es ruido visual.
  Widget _badged(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
  }
}
