import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/theme_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appCardBorder),
            ),
            child: Column(
              children: [
                _ListTile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Theme',
                  subtitle: _themeLabel(theme.mode),
                  trailing: DropdownButton<ThemeMode>(
                    value: theme.mode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (m) {
                      if (m != null) theme.setMode(m);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appCardBorder),
            ),
            child: state.history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No injection history yet.', style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant)),
                  )
                : Column(
                    children: [
                      for (final h in state.history.take(50))
                        _HistoryTile(
                          heroName: h.heroName,
                          skinName: h.skinName,
                          timestamp: h.timestamp,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton.icon(
                          onPressed: () => state.clearHistory(),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear history'),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text('About', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 20, color: context.appSecondary),
                    const SizedBox(width: 10),
                    const Text('Yuyu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text('v5.0.0', style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'A community skin injector for Mobile Legends: Bang Bang. '
                  'All skins are the property of Moonton; this tool is for '
                  'personal use only.',
                  style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Follow system',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ListTile({required this.icon, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.appPrimaryDark),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String heroName;
  final String skinName;
  final int timestamp;

  const _HistoryTile({required this.heroName, required this.skinName, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.history, size: 18, color: context.appOnSurfaceVariant),
      title: Text(skinName, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(heroName, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      trailing: Text(
        _formatTime(timestamp),
        style: TextStyle(fontSize: 11, color: context.appOnSurfaceVariant),
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
