import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YuyuApp());
}

class YuyuApp extends StatelessWidget {
  const YuyuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AppState()..init()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Yuyu',
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) {
        AppColors.setThemeBrightness(Theme.of(context).brightness);
        return child!;
      },
      home: const HomeShell(),
    );
  }
}
