import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  Future<void> _confirmAdvancedRestore(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced restore?'),
        content: Text(
            'Clears repair markers and re-applies ${state.favorites.length} cached favorite skin(s). '
            'The game must be closed while this runs. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run restore'),
          ),
        ],
      ),
    );
    if (ok == true) state.advancedRestoreAllFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final running = state.operation.running;

    return Scaffold(
      appBar: AppBar(title: const Text('Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EnvironmentCard(state: state),
          const SizedBox(height: 16),
          _ShizukuGuideCard(state: state),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.restore,
            color: context.appSecondary,
            title: 'Advanced restore',
            subtitle: 'Clears the game repair markers then re-injects every cached '
                'favorite skin. Use this after the game repaired or reverted skins.',
            trailing: FilledButton(
              onPressed: state.favorites.isEmpty || running
                  ? null
                  : () => _confirmAdvancedRestore(context),
              child: const Text('Run'),
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.manage_search,
            color: context.appPrimary,
            title: 'Check injected skins',
            subtitle: 'Re-verify which skins are still present in the game files '
                'and refresh the injected badge.',
            trailing: TextButton.icon(
              onPressed: running ? null : () => state.refreshInjectedStatus(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check'),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Make sure Mobile Legends: Bang Bang is fully closed before running '
              'any restore or injection operation.',
              style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  final AppState state;

  const _EnvironmentCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final game = state.game;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Environment',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _EnvRow(
            icon: Icons.sports_esports,
            label: 'Game',
            value: game == null ? 'Not detected' : game.packageName,
            ok: game != null,
          ),
          _EnvRow(
            icon: Icons.folder_open,
            label: 'Storage access',
            value: state.storageGranted ? 'Granted' : 'Not granted',
            ok: state.storageGranted,
            onTap: state.storageGranted
                ? null
                : () => context.read<AppState>().grantStorage(),
          ),
          _EnvRow(
            icon: Icons.shield_outlined,
            label: 'Shizuku',
            value: state.shizukuState,
            ok: state.shizukuState == 'granted',
            onTap: state.shizukuState == 'granted'
                ? null
                : () => context.read<AppState>().requestShizukuPermission(),
          ),
          if (!state.storageGranted) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.read<AppState>().grantStorage(),
              icon: const Icon(Icons.folder_open),
              label: const Text('Allow storage access'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.gradientEnd,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnvRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final VoidCallback? onTap;

  const _EnvRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: ok ? Colors.white : context.appWarning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'Fix',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ShizukuGuideCard extends StatelessWidget {
  final AppState state;

  const _ShizukuGuideCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isBound = state.shizukuState == 'granted' || state.shizukuState == 'bound';

    return ExpansionTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      backgroundColor: context.appSurface,
      collapsedBackgroundColor: context.appSurface,
      leading: Icon(
        Icons.help_outline,
        color: isBound ? context.appSuccess : context.appPrimaryDark,
      ),
      title: const Text(
        'Android 11+ Shizuku Setup Guide',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        isBound ? 'Shizuku connected & active' : 'Required to access game data files on Android 11+',
        style: TextStyle(
          fontSize: 12,
          color: isBound ? context.appSuccess : context.appOnSurfaceVariant,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              const Text(
                'Android 11+ restricts direct access to /Android/data. Shizuku grants elevated access without root:',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              _stepItem('1', 'Install Shizuku app from Play Store or GitHub.'),
              _stepItem('2', 'Enable Developer Options in phone settings.'),
              _stepItem('3', 'Turn on Wireless Debugging in Developer Options.'),
              _stepItem('4', 'Open Shizuku -> tap "Pairing" -> pair via Wireless Debugging code.'),
              _stepItem('5', 'Tap "Start" in Shizuku.'),
              _stepItem('6', 'Return to Yuyu and tap "Fix" or "Request Permission".'),
              const SizedBox(height: 12),
              if (!isBound)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AppState>().requestShizukuPermission(),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('Request Shizuku Permission'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.gradientStart,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
