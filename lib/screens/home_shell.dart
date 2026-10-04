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

  static const _drawerItems = [
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Heroes'),
    (Icons.palette_outlined, Icons.palette, 'Cosmetics'),
    (Icons.favorite_outline, Icons.favorite, 'Favorites'),
    (Icons.restore_outlined, Icons.restore, 'Restore'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
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
          for (var i = 0; i < _drawerItems.length; i++)
            NavigationDrawerDestination(
              icon: Icon(_drawerItems[i].$1),
              selectedIcon: Icon(_drawerItems[i].$2),
              label: Text(_drawerItems[i].$3),
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