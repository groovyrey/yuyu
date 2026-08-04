import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final injected = state.injected.contains('${favorite.heroId}:${favorite.skinName}');
    final injecting = state.operation.running && state.operation.message.contains(favorite.skinName);

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: AppImage(url: favorite.skinImage, fit: BoxFit.cover),
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
                  if (injecting)
                    const LinearProgressIndicator(minHeight: 3)
                  else
                    Row(
                      children: [
                        if (injected) ...[
                          Icon(Icons.check_circle, size: 14, color: context.appSuccess),
                          const SizedBox(width: 4),
                          Text(
                            'Injected',
                            style: TextStyle(fontSize: 11, color: context.appSuccess, fontWeight: FontWeight.w600),
                          ),
                        ] else
                          FilledButton(
                            onPressed: state.operation.running
                                ? null
                                : () => state.injectSkinFromFavorite(favorite),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Inject'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove from favorites',
            onPressed: () async {
              await state.removeFavorite(favorite.heroId, favorite.skinName);
            },
            icon: Icon(Icons.close, size: 20, color: context.appOnSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
