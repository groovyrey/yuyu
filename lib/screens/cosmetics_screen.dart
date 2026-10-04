import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_image.dart';

class CosmeticsScreen extends StatefulWidget {
  const CosmeticsScreen({super.key});

  @override
  State<CosmeticsScreen> createState() => _CosmeticsScreenState();
}

class _CosmeticsScreenState extends State<CosmeticsScreen> {
  CosmeticCategory _category = CosmeticCategory.newlyAdded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadCosmetics(_category);
    });
  }

  void _selectCategory(CosmeticCategory category) {
    if (_category == category) return;
    setState(() => _category = category);
    context.read<AppState>().loadCosmetics(category);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmetics'),
        leading: const AppDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: state.operation.running
                ? null
                : () => state.reloadCosmetics(_category),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              children: [
                for (final category in CosmeticCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: category == _category
                        ? FilledButton(
                            onPressed: () => _selectCategory(category),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 34),
                            ),
                            child: Text(category.label),
                          )
                        : OutlinedButton(
                            onPressed: () => _selectCategory(category),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 34),
                            ),
                            child: Text(category.label),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(AppState state) {
    final items = state.cosmetics(_category);
    final loading = state.isCosmeticLoading(_category);
    final error = state.cosmeticError(_category);

    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return _ErrorRetry(
        message: error,
        onRetry: () => state.reloadCosmetics(_category),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet',
          style: TextStyle(color: context.appOnSurfaceVariant),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _CosmeticCard(category: _category, item: item);
      },
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  final CosmeticCategory category;
  final CosmeticItem item;

  const _CosmeticCard({required this.category, required this.item});

  Future<void> _confirmRestore(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove injection mark?'),
        content: Text(
            '${item.title} will be marked as not injected. The files stay on '
            'disk until the game repairs them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) state.restoreCosmetic(category, item);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final injected = state.isCosmeticInjected(category, item.title);
    final injecting =
        state.operation.running && state.operation.message.contains(item.title);
    final available = item.sc.isNotEmpty && item.img.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: injected
              ? context.appPrimary.withValues(alpha: 0.6)
              : context.appCardBorder,
          width: injected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(url: item.img, fit: BoxFit.cover),
                if (injected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.appPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Injected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (injecting)
                  Column(
                    children: [
                      const LinearProgressIndicator(minHeight: 4),
                      const SizedBox(height: 4),
                      Text(
                        'Injecting...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appOnSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (injected)
                  OutlinedButton(
                    onPressed: state.operation.running
                        ? null
                        : () => _confirmRestore(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Injected'),
                  )
                else
                  FilledButton(
                    onPressed: available && !state.operation.running
                        ? () => state.injectCosmetic(category, item)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Inject'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: context.appOnSurfaceVariant),
            const SizedBox(height: 12),
            const Text(
              'Could not load cosmetics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}