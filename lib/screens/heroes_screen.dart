import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import 'hero_detail_screen.dart';

class HeroesScreen extends StatefulWidget {
  const HeroesScreen({super.key});

  @override
  State<HeroesScreen> createState() => _HeroesScreenState();
}

class _HeroesScreenState extends State<HeroesScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _role;

  static const _baseClasses = ['Assassin', 'Fighter', 'Mage', 'Marksman', 'Support', 'Tank'];

  static List<String> _roleTokens(String role) =>
      role.split(RegExp(r'[\s/]+')).where((t) => t.isNotEmpty).toList();

  /// Only the individual base classes, never mixed roles like
  /// "Assassin Fighter". A hero with a mixed role is matched against each of
  /// its individual classes separately.
  List<String> _roles(List<HeroEntry> heroes) {
    final seen = <String>{};
    for (final h in heroes) {
      for (final token in _roleTokens(h.heroInfo.role)) {
        if (_baseClasses.contains(token)) seen.add(token);
      }
    }
    return _baseClasses.where(seen.contains).toList();
  }

  List<HeroEntry> _filtered(List<HeroEntry> heroes) {
    var list = heroes;
    if (_role != null) {
      list = list
          .where((h) => _roleTokens(h.heroInfo.role).contains(_role))
          .toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((h) => h.heroInfo.name.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) => a.heroInfo.name.toLowerCase().compareTo(b.heroInfo.name.toLowerCase()));
    return list;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final heroes = state.heroes;
    final roles = _roles(heroes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heroes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: state.loading ? null : state.reloadHeroes,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search heroes',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: context.appSurface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (roles.length > 1)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _role == null,
                      onSelected: (_) => setState(() => _role = null),
                    ),
                  ),
                  for (final role in roles)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(role),
                        selected: _role == role,
                        onSelected: (_) => setState(() => _role = role),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildBody(state, heroes)),
        ],
      ),
    );
  }

  Widget _buildBody(AppState state, List<HeroEntry> heroes) {
    if (state.loading && heroes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null && heroes.isEmpty) {
      return _ErrorRetry(message: state.loadError!, onRetry: state.reloadHeroes);
    }
    final filtered = _filtered(heroes);
    if (filtered.isEmpty) {
      return Center(
        child: Text('No heroes found', style: TextStyle(color: context.appOnSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hero = filtered[index];
        return HeroCard(hero: hero);
      },
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
              'Could not load heroes',
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

class HeroCard extends StatelessWidget {
  final HeroEntry hero;

  const HeroCard({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final role = hero.heroInfo.role
        .split(RegExp(r'[\s/]+'))
        .where((t) => t.isNotEmpty)
        .join(' / ');

    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HeroDetailScreen(hero: hero)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ClipOval(
                  child: AppImage(
                    url: hero.heroInfo.portraitIcon,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.heroInfo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: context.appOnSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
