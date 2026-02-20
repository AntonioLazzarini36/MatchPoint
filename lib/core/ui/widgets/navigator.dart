import 'package:flutter/material.dart';
import '../../../features/auth/screens/discovery/discovery_screen.dart';
import '../../../features/auth/screens/matches/matches_screen.dart';
import '../../../features/auth/screens/profile/profile_screen.dart';

class NavigatorShell extends StatefulWidget {
  const NavigatorShell({super.key});

  @override
  State<NavigatorShell> createState() => NavigatorShellState();
}

class NavigatorShellState extends State<NavigatorShell> {
  int _index = 0;

  final _screens = const [
    DiscoveryScreen(),
    MatchesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Discovery',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}