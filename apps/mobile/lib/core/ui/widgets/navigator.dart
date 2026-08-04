import 'package:flutter/material.dart';

import '../../network/notification_counts.dart';
import '../../../features/discovery/screens/discovery_screen.dart';
import '../../../features/matches/screens/matches_screen.dart';
import '../../../features/matches/screens/upcoming_screen.dart';
import '../../../features/profile/screens/profile_screen.dart';

class NavigatorShell extends StatefulWidget {
  const NavigatorShell({super.key});

  @override
  State<NavigatorShell> createState() => NavigatorShellState();
}

class NavigatorShellState extends State<NavigatorShell> {
  int _index = 0;

  /// "Partidos" va justo detrás de Matches: el recorrido natural es
  /// match -> hablar -> quedar, y tener el plan a un toque es la mitad del
  /// producto ("organizar el partido", no sólo hacer match).
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
  }

  @override
  void dispose() {
    _counts.removeListener(_onCounts);
    _counts.stop();
    super.dispose();
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
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Discovery',
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
            label: 'Matches',
          ),
          NavigationDestination(
            icon: _badged(
              const Icon(Icons.event_outlined),
              _counts.pendingProposals,
            ),
            selectedIcon: _badged(
              const Icon(Icons.event),
              _counts.pendingProposals,
            ),
            label: 'Partidos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Sin contador no se dibuja nada: un badge vacío es ruido visual.
  Widget _badged(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}
