import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_image.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> _confirmInjectAll(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inject all favorites?'),
        content: Text(
            'This will download and inject ${state.favorites.length} skin(s) into the game. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Inject all'),
          ),
        ],
      ),
    );
    if (ok == true) state.injectAllFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favorites;
    final running = state.operation.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: const AppDrawerButton(),
        actions: [
          if (favorites.isNotEmpty && !running)
            TextButton.icon(
              onPressed: () => _confirmInjectAll(context),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Inject all'),
            ),
        ],
      ),
      body: favorites.isEmpty
          ? const _EmptyFavorites()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _FavoriteTile(favorite: favorites[index]),
            ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border_rounded, size: 56, color: context.appOnSurfaceVariant),
          const SizedBox(height: 12),
          const Text(
            'No favorites yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the star on any skin to add it here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final Favorite favorite;

  const _FavoriteTile({required this.favorite});

  String get _key => '${favorite.heroId}:${favorite.skinName}';

  void _showActions(BuildContext context, AppState state, bool injected) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(injected ? Icons.refresh : Icons.bolt),
              title: Text(injected ? 'Re-inject' : 'Inject'),
              subtitle: Text(
                injected
                    ? 'Replace the active files with this skin'
                    : 'Download and inject this skin',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                state.injectSkinFromFavorite(favorite);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.appError),
              title: Text('Remove from favorites',
                  style: TextStyle(color: context.appError)),
              onTap: () {
                Navigator.pop(sheetContext);
                state.removeFavorite(favorite.heroId, favorite.skinName);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final injected = state.isActiveSkin(favorite.heroId, favorite.skinName);
    final op = state.operation;
    final active = op.running && op.activeKey == _key;

    return Material(
      color: context.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.appCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: op.running
            ? null
            : () => _showActions(context, state, injected),
        child: Row(
          children: [
            const SizedBox(width: 12),
            SizedBox(
              width: 84,
              height: 84,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImage(
                  url: favorite.skinImage,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.skinName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      favorite.heroName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    if (active) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: op.stepFraction,
                          minHeight: 4,
                          backgroundColor:
                              context.appPrimary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(context.appPrimary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        op.stepLabel.isEmpty ? 'Working...' : op.stepLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appOnSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else if (injected)
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: context.appSuccess),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                                fontSize: 11,
                                color: context.appSuccess,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Tap to inject',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.appOnSurfaceVariant,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.more_vert, size: 20, color: context.appOnSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
