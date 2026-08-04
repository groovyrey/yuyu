import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';

class HeroDetailScreen extends StatelessWidget {
  final HeroEntry hero;

  const HeroDetailScreen({super.key, required this.hero});

  String _findSkinUrl(HeroEntry hero, Skin skin) {
    for (final d in hero.defaultSkins) {
      if (d.skinInfo == skin.id) return d.sc;
    }
    for (final group in hero.skinToSkin) {
      for (final s in group) {
        if (s.skinInfo == skin.id) return s.sc;
      }
    }
    if (hero.skinToSkin.isNotEmpty && hero.skinToSkin.first.isNotEmpty) {
      return hero.skinToSkin.first.first.sc;
    }
    return '';
  }

  Skin? _skinForId(HeroEntry hero, int? id) {
    if (id == null) return null;
    for (final s in hero.skins) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The last skin that has an image, falling back to the hero portrait.
  String _bannerImage(HeroEntry hero) {
    for (final s in hero.skins.reversed) {
      if (s.image.isNotEmpty) return s.image;
    }
    return hero.heroInfo.portraitIcon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: context.appSurface,
            foregroundColor: context.appOnSurface,
            flexibleSpace: FlexibleSpaceBar(
              background: AppImage(url: _bannerImage(hero), fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(child: _Header(hero: hero)),
          SliverToBoxAdapter(child: _Description(hero: hero)),
          if (hero.skill.skillInfo.isNotEmpty)
            SliverToBoxAdapter(child: _Skills(skill: hero.skill)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Skins (${hero.skins.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final skin = hero.skins[index];
                  return _SkinCard(
                    hero: hero,
                    skin: skin,
                    downloadUrl: _findSkinUrl(hero, skin),
                  );
                },
                childCount: hero.skins.length,
              ),
            ),
          ),
          if (hero.skinToSkin.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Skin to Skin',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hero.skinToSkin.length,
                  itemBuilder: (context, index) {
                    final group = hero.skinToSkin[index];
                    final from = _skinForId(hero, group.isEmpty ? null : group.first.skinInfo);
                    final to = _skinForId(hero, group.isEmpty ? null : group.last.skinInfo);
                    return _SkinToSkinCard(
                      hero: hero,
                      from: from,
                      to: to,
                      sc: group.isEmpty ? '' : group.last.sc,
                    );
                  },
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final HeroEntry hero;

  const _Header({required this.hero});

  @override
  Widget build(BuildContext context) {
    final info = hero.heroInfo;
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            [info.role, info.lane].where((e) => e.isNotEmpty).join(' • '),
            style: TextStyle(fontSize: 14, color: context.appPrimaryDark, fontWeight: FontWeight.w600),
          ),
          if (info.price.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: _priceRows(info.price),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _priceRows(String price) {
    final parts = price.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final widgets = <Widget>[];
    if (parts.isNotEmpty) {
      widgets.add(_PricePill(icon: Icons.payments_outlined, value: parts.first));
    }
    if (parts.length > 1) {
      widgets.add(const SizedBox(width: 10));
      widgets.add(_PricePill(icon: Icons.diamond_outlined, value: parts[1]));
    }
    return widgets;
  }
}

class _PricePill extends StatelessWidget {
  final IconData icon;
  final String value;

  const _PricePill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appOnSurfaceVariant),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  final HeroEntry hero;

  const _Description({required this.hero});

  @override
  Widget build(BuildContext context) {
    final info = hero.heroInfo;
    final stats = info.baseStats;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.quote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '"${info.quote}"',
                style: TextStyle(
                  color: context.appPrimaryDark,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          _infoRow(context, 'Specialty', info.specialty),
          if (info.releaseDate.isNotEmpty) _infoRow(context, 'Released', info.releaseDate),
          if (info.price.isNotEmpty) _infoRow(context, 'Price', info.price),
          if (stats.hp.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 2),
              child: Text('Base Stats', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            _infoRow(context, 'HP', stats.hp),
            if (stats.mana.isNotEmpty) _infoRow(context, 'Mana', stats.mana),
            _infoRow(context, 'Physical Attack', stats.physicalAttack),
            _infoRow(context, 'Physical Defense', stats.physicalDefense),
            if (stats.movementSpeed.isNotEmpty) _infoRow(context, 'Move Speed', stats.movementSpeed),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: context.appOnSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

class _Skills extends StatelessWidget {
  final Skill skill;

  const _Skills({required this.skill});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < skill.skillInfo.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _SkillTile(
              info: skill.skillInfo[i],
              type: i < skill.skillType.length ? skill.skillType[i] : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final SkillInfo info;
  final String? type;

  const _SkillTile({required this.info, this.type});

  @override
  Widget build(BuildContext context) {
    final iconUrl = info.icons.isNotEmpty ? info.icons.first : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (iconUrl.isNotEmpty)
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: context.appSurfaceVariant,
            ),
            clipBehavior: Clip.antiAlias,
            child: AppImage(url: iconUrl, fit: BoxFit.cover),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    info.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (type != null && type!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.appPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.appPrimaryDark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                info.description,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appOnSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkinCard extends StatelessWidget {
  final HeroEntry hero;
  final Skin skin;
  final String downloadUrl;

  const _SkinCard({required this.hero, required this.skin, required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isFavorite = state.isFavorite(hero.heroInfo.id, skin.name);
    final injected = state.injected.contains('${hero.heroInfo.id}:${skin.name}');
    // True if THIS specific skin is the active one for this hero.
    // Any other skin for the same hero will have injected==false and can be re-injected.
    final injecting = state.operation.running && state.operation.message.contains(skin.name);
    final available = downloadUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: injected ? context.appPrimary.withValues(alpha: 0.6) : context.appCardBorder,
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
                AppImage(url: skin.image, fit: BoxFit.cover),
                if (injected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.appPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        if (isFavorite) {
                          await state.removeFavorite(hero.heroInfo.id, skin.name);
                        } else {
                          await state.addFavorite(
                              hero, skin.name, skin.image, downloadUrl);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFavorite ? context.appWarning : context.appOnSurface,
                          size: 22,
                        ),
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
                  skin.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  available ? skin.type : 'Not available',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: context.appPrimaryDark),
                ),
                const SizedBox(height: 8),
                if (injecting)
                  const LinearProgressIndicator(minHeight: 3)
                else
                  FilledButton(
                    // Disabled only when THIS skin is already the active one,
                    // or when an operation is running, or no URL is available.
                    onPressed: available && !state.operation.running && !injected
                        ? () => state.injectSkin(hero, skin.name, skin.image, downloadUrl)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: Text(injected ? 'Active ✓' : 'Inject'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinToSkinCard extends StatelessWidget {
  final HeroEntry hero;
  final Skin? from;
  final Skin? to;
  final String sc;

  const _SkinToSkinCard({required this.hero, required this.from, required this.to, required this.sc});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final label = '${from?.name ?? '?'} → ${to?.name ?? '?'}';
    final injecting = state.operation.running && state.operation.message.contains('→');
    final enabled = sc.isNotEmpty && !state.operation.running && from != null && to != null;

    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: AppImage(url: to?.image ?? '', fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (injecting)
                  const LinearProgressIndicator(minHeight: 3)
                else
                  FilledButton(
                    onPressed: enabled
                        ? () => state.injectSkinToSkin(hero, from!.name, to!.name, sc)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Transform'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
