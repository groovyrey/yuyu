import 'package:flutter/material.dart';

import '../widgets/operation_banner.dart';
import 'cosmetics_screen.dart';
import 'favorites_screen.dart';
import 'heroes_screen.dart';
import 'restore_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    HeroesScreen(),
    CosmeticsScreen(),
    FavoritesScreen(),
    RestoreScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: 'Heroes',
    ),
    NavigationDestination(
      icon: Icon(Icons.palette_outlined),
      selectedIcon: Icon(Icons.palette),
      label: 'Cosmetics',
    ),
    NavigationDestination(
      icon: Icon(Icons.favorite_outline),
      selectedIcon: Icon(Icons.favorite),
      label: 'Favorites',
    ),
    NavigationDestination(
      icon: Icon(Icons.restore_outlined),
      selectedIcon: Icon(Icons.restore),
      label: 'Restore',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          Navigator.pop(context);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Yuyu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          for (var i = 0; i < _destinations.length; i++)
            NavigationDrawerDestination(
              icon: _destinations[i].icon,
              selectedIcon: _destinations[i].selectedIcon,
              label: _destinations[i].label,
            ),
        ],
      ),
      body: Column(
        children: [
          const OperationBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: _screens),
          ),
        ],
      ),
    );
  }
}