import 'package:flutter/material.dart';

/// Opens the app-wide navigation drawer from a screen's own AppBar. The
/// drawer lives on the outer shell Scaffold, so the root-most ScaffoldState
/// is located instead of the screen's own one.
class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Open menu',
      icon: const Icon(Icons.menu),
      onPressed: () {
        context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
      },
    );
  }
}