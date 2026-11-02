import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/lumina_api.dart';
import '../models/models.dart';
import '../services/engine_service.dart';

class OperationState {
  final bool running;
  final String message;
  final int done;
  final int total;
  final int step;
  final int stepTotal;
  final String stepLabel;
  final String activeKey;

  const OperationState({
    this.running = false,
    this.message = '',
    this.done = 0,
    this.total = 0,
    this.step = 0,
    this.stepTotal = 0,
    this.stepLabel = '',
    this.activeKey = '',
  });

  double get stepFraction =>
      stepTotal <= 0 ? 0 : (step / stepTotal).clamp(0.0, 1.0);

  double get overallFraction {
    if (total <= 0) return stepFraction;
    return ((done + stepFraction) / total).clamp(0.0, 1.0);
  }

  OperationState copyWith({
    bool? running,
    String? message,
    int? done,
    int? total,
    int? step,
    int? stepTotal,
    String? stepLabel,
    String? activeKey,
  }) =>
      OperationState(
        running: running ?? this.running,
        message: message ?? this.message,
        done: done ?? this.done,
        total: total ?? this.total,
        step: step ?? this.step,
        stepTotal: stepTotal ?? this.stepTotal,
        stepLabel: stepLabel ?? this.stepLabel,
        activeKey: activeKey ?? this.activeKey,
      );
}

class AppState extends ChangeNotifier {
  List<HeroEntry> _heroes = [];
  bool _loading = true;
  String? _loadError;

  List<Favorite> _favorites = [];
  List<InjectedSkin> _manifest = [];
  List<History> _history = [];
  Set<String> _injectedCosmetics = {};

  final Map<CosmeticCategory, List<CosmeticItem>> _cosmetics = {};
  final Map<CosmeticCategory, bool> _cosmeticLoading = {};
  final Map<CosmeticCategory, String?> _cosmeticError = {};

  OperationState _operation = const OperationState();
  OperationState get operation => _operation;

  GameTarget? _game;
  bool _storageGranted = false;
  String _shizukuState = 'unavailable';

  StreamSubscription<String>? _resumeSub;

  Completer<void>? _opLock;

  List<HeroEntry> get heroes => _heroes;
  bool get loading => _loading;
  String? get loadError => _loadError;
  List<Favorite> get favorites => _favorites;
  int get restoreTargetCount => _restoreTargets().length;
  GameTarget? get game => _game;
  bool get storageGranted => _storageGranted;
  String get shizukuState => _shizukuState;

  List<CosmeticItem> cosmetics(CosmeticCategory category) =>
      _cosmetics[category] ?? const [];

  bool isCosmeticLoading(CosmeticCategory category) =>
      _cosmeticLoading[category] ?? false;

  String? cosmeticError(CosmeticCategory category) =>
      _cosmeticError[category];

  bool isCosmeticInjected(CosmeticCategory category, String title) =>
      _injectedCosmetics.contains(_cosmeticKey(category, title));

  bool get isReady {
    if (_game == null || !_storageGranted) return false;
    if (_needsShizuku && _shizukuState != 'bound') return false;
    return true;
  }

  bool get _needsShizuku => Platform.isAndroid;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(prefs);
    notifyListeners();

    _loadHeroes();
    await refreshEnv();
    cleanupCache();

    _resumeSub = EngineService.onResume.listen((_) => refreshEnv());
  }

  @override
  void dispose() {
    _resumeSub?.cancel();
    super.dispose();
  }

  void _loadFromPrefs(SharedPreferences prefs) {
    _favorites = _decodeList(prefs.getString('favorites'))
        .map((e) => Favorite.fromJson(e))
        .toList();
    _manifest = _decodeList(prefs.getString('injected_manifest'))
        .map((e) => InjectedSkin.fromJson(e))
        .toList();
    _history = _decodeList(prefs.getString('history'))
        .map((e) => History.fromJson(e))
        .toList();
    _injectedCosmetics = _decodeList(prefs.getString('injected_cosmetics'))
        .map((e) => e['key'] as String? ?? '')
        .where((k) => k.isNotEmpty)
        .toSet();
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshEnv() async {
    _game = await EngineService.findGame();
    _storageGranted = await EngineService.storageGranted();
    _shizukuState = await EngineService.shizukuState();
    notifyListeners();
  }

  Future<void> requestShizukuPermission() async {
    await EngineService.requestShizukuPermission();
    await Future<void>.delayed(const Duration(seconds: 1));
    await refreshEnv();
  }

  Future<void> bindShizuku() async {
    await EngineService.bindShizuku();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await refreshEnv();
  }

  Future<void> grantStorage() async {
    await EngineService.openStorageSettings();
  }

  void dismissOperation() {
    if (!_operation.running) {
      _operation = const OperationState();
      notifyListeners();
    }
  }

  Future<void> _loadHeroes() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _heroes = await LuminaApi.fetchHeroes();
    } catch (e) {
      _loadError = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> reloadHeroes() => _loadHeroes();

  bool isFavorite(int heroId, String skinName) =>
      _favorites.any((f) => f.heroId == heroId && f.skinName == skinName);

  Future<void> addFavorite(HeroEntry hero, String skinName, String image, String sc) async {
    if (isFavorite(hero.heroInfo.id, skinName)) return;
    _favorites.removeWhere((f) => f.heroId == hero.heroInfo.id);
    _favorites.add(Favorite(
      heroName: hero.heroInfo.name,
      heroId: hero.heroInfo.id,
      skinName: skinName,
      skinImage: image,
      skinSc: sc,
    ));
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> removeFavorite(int heroId, String skinName) async {
    _favorites.removeWhere((f) => f.heroId == heroId && f.skinName == skinName);
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'favorites',
      jsonEncode(_favorites.map((f) => f.toJson()).toList()),
    );
  }

  String _safeName(Favorite fav) =>
      '${fav.heroName}-${fav.skinName}'.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');

  Future<File> _cachedZip(Favorite fav) async {
    final cache = await EngineService.cacheDir();
    await cache.create(recursive: true);
    return File('${cache.path}/${_safeName(fav)}.zip');
  }

  Future<void> _deleteCachedZip(File zip) async {
    try {
      if (zip.existsSync()) await zip.delete();
    } catch (_) {}
  }

  Future<void> cleanupCache({int maxFiles = 50, int maxAgeDays = 7}) async {
    try {
      final cache = await EngineService.cacheDir();
      if (!await cache.exists()) return;
      final files = cache.listSync().whereType<File>().toList();
      final now = DateTime.now();
      for (final f in files) {
        try {
          final stat = f.statSync();
          final age = now.difference(stat.modified).inDays;
          if (age > maxAgeDays) {
            await f.delete();
            continue;
          }
        } catch (_) {}
      }
      final remaining = cache.listSync().whereType<File>().toList();
      if (remaining.length > maxFiles) {
        remaining.sort((a, b) {
          try {
            return a.statSync().modified.compareTo(b.statSync().modified);
          } catch (_) {
            return 0;
          }
        });
        for (var i = 0; i < remaining.length - maxFiles; i++) {
          try {
            await remaining[i].delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _acquireOpLock() async {
    while (_opLock != null) {
      await _opLock!.future;
    }
    _opLock = Completer<void>();
  }

  void _releaseOpLock() {
    final c = _opLock;
    _opLock = null;
    c?.complete();
  }

  static const int _injectStepCount = 5;

  String _skinKey(Favorite fav) => '${fav.heroId}:${fav.skinName}';

  bool isActiveSkin(int heroId, String skinName) =>
      _manifest.any((m) => m.heroId == heroId && m.skinName == skinName);

  Future<void> _injectFavorite(
    Favorite fav, {
    required int index,
    required int count,
  }) async {
    final key = _skinKey(fav);
    void report(int step, String label) {
      _operation = OperationState(
        running: true,
        message: 'Injecting ${fav.skinName}...',
        done: index,
        total: count,
        step: step,
        stepTotal: _injectStepCount,
        stepLabel: label,
        activeKey: key,
      );
      notifyListeners();
    }

    report(0, 'Preparing');
    if (fav.skinSc.isEmpty) throw 'No download URL for ${fav.skinName}';
    final game = await EngineService.findGame();
    if (game == null) throw 'Mobile Legends is not installed';

    final zip = await _cachedZip(fav);
    final entries = <String>[];
    var extractionStarted = false;

    try {
      var zipEntries = zip.existsSync()
          ? await EngineService.listZipEntries(zip.path)
          : const <(String, int)>[];
      report(1, zipEntries.isEmpty ? 'Downloading skin' : 'Using cached skin');
      if (zipEntries.isEmpty) {
        await _deleteCachedZip(zip);
        final dl = await EngineService.downloadFile(fav.skinSc, zip.path);
        if (!dl.ok) {
          throw 'Download failed for ${fav.skinName}'
              '${dl.error != null ? ': ${dl.error}' : ''}';
        }
        if (!zip.existsSync() || zip.lengthSync() == 0) {
          throw 'Download produced empty file for ${fav.skinName}';
        }
        zipEntries = await EngineService.listZipEntries(zip.path);
      }

      report(2, 'Validating archive');
      if (zipEntries.isEmpty) {
        throw 'Downloaded file is not a valid zip for ${fav.skinName}';
      }
      entries.addAll(zipEntries.map((e) => e.$1));

      report(3, 'Extracting files');
      extractionStarted = true;
      final uz = await EngineService.unzip(zip.path, game.assetsDir);
      if (!uz.ok) {
        throw 'Extraction failed for ${fav.skinName}'
            '${uz.error != null ? ': ${uz.error}' : ''}';
      }

      report(4, 'Cleaning up old files');
      await _removeStaleFiles(game, fav.heroId, entries);

      _recordInjected(InjectedSkin(
        heroName: fav.heroName,
        heroId: fav.heroId,
        skinName: fav.skinName,
        skinImage: fav.skinImage,
        skinSc: fav.skinSc,
        files: entries,
      ));
      _addHistory(fav);
    } catch (e) {
      if (extractionStarted) {
        await _deleteAssetFiles(game, entries);
      }
      await _deleteCachedZip(zip);
      rethrow;
    }
  }

  Future<void> _removeStaleFiles(
      GameTarget game, int heroId, List<String> newFiles) async {
    final next = newFiles.toSet();
    final previous = _manifest
        .where((m) => m.heroId == heroId)
        .expand((m) => m.files)
        .toSet();
    final referencedByOtherHeroes = _manifest
        .where((m) => m.heroId != heroId)
        .expand((m) => m.files)
        .toSet();
    final stale = previous
        .where((p) => !next.contains(p) && !referencedByOtherHeroes.contains(p))
        .toList();
    if (stale.isEmpty) return;
    await _deleteAssetFiles(game, stale);
  }

  Future<void> _deleteAssetFiles(GameTarget game, Iterable<String> paths) async {
    final list = paths.map((p) => '${game.assetsDir}/$p').toList();
    if (list.isEmpty) return;
    try {
      await EngineService.deleteFiles(list);
    } catch (_) {}
  }

  void _finishSingle(String message) {
    _operation = OperationState(
      running: false,
      message: message,
      done: 1,
      total: 1,
      step: _injectStepCount,
      stepTotal: _injectStepCount,
      stepLabel: 'Done',
    );
  }

  Future<void> injectSkin(HeroEntry hero, String skinName, String image, String sc) async {
    if (_operation.running) return;
    _operation = OperationState(
      running: true,
      message: 'Injecting $skinName...',
      total: 1,
      stepTotal: _injectStepCount,
    );
    notifyListeners();
    try {
      await _acquireOpLock();
      try {
        await _injectFavorite(Favorite(
          heroName: hero.heroInfo.name,
          heroId: hero.heroInfo.id,
          skinName: skinName,
          skinImage: image,
          skinSc: sc,
        ), index: 0, count: 1);
        _finishSingle('Injected: $skinName');
      } finally {
        _releaseOpLock();
      }
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> injectSkinToSkin(
      HeroEntry hero, String fromSkin, String toSkin, String sc) async {
    if (_operation.running) return;
    final label = '$fromSkin → $toSkin';
    _operation = OperationState(
      running: true,
      message: 'Injecting $label...',
      total: 1,
      stepTotal: _injectStepCount,
    );
    notifyListeners();
    try {
      await _acquireOpLock();
      try {
        await _injectFavorite(Favorite(
          heroName: hero.heroInfo.name,
          heroId: hero.heroInfo.id,
          skinName: label,
          skinImage: '',
          skinSc: sc,
        ), index: 0, count: 1);
        _finishSingle('Injected: $label');
      } finally {
        _releaseOpLock();
      }
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> injectSkinFromFavorite(Favorite fav) async {
    if (_operation.running) return;
    _operation = OperationState(
      running: true,
      message: 'Injecting ${fav.skinName}...',
      total: 1,
      stepTotal: _injectStepCount,
    );
    notifyListeners();
    try {
      await _acquireOpLock();
      try {
        await _injectFavorite(fav, index: 0, count: 1);
        _finishSingle('Injected: ${fav.skinName}');
      } finally {
        _releaseOpLock();
      }
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> injectAllFavorites() async {
    if (_operation.running || _favorites.isEmpty) return;
    final all = List<Favorite>.from(_favorites);
    final pending =
        all.where((f) => !isActiveSkin(f.heroId, f.skinName)).toList();
    final skipped = all.length - pending.length;

    if (pending.isEmpty) {
      _operation = OperationState(
        running: false,
        message: 'All ${all.length} favorites are already injected',
        done: all.length,
        total: all.length,
        step: _injectStepCount,
        stepTotal: _injectStepCount,
        stepLabel: 'Done',
      );
      notifyListeners();
      return;
    }

    _operation = OperationState(
      running: true,
      message: 'Injecting favorites...',
      total: pending.length,
      stepTotal: _injectStepCount,
    );
    notifyListeners();

    await _acquireOpLock();
    try {
      final failures = <String>[];
      for (var i = 0; i < pending.length; i++) {
        final fav = pending[i];
        try {
          await _injectFavorite(fav, index: i, count: pending.length);
        } catch (e) {
          failures.add('${fav.skinName}: ${_msg(e)}');
        }
      }

      final ok = pending.length - failures.length;
      final maxShow = 8;
      final shown = failures.take(maxShow).join('\n');
      final extra = failures.length > maxShow
          ? '\n...and ${failures.length - maxShow} more'
          : '';
      _operation = OperationState(
        running: false,
        message: 'Injected $ok, skipped $skipped, failed ${failures.length}'
            '${failures.isNotEmpty ? '\n$shown$extra' : ''}',
        done: ok,
        total: pending.length,
        step: _injectStepCount,
        stepTotal: _injectStepCount,
        stepLabel: 'Done',
      );
    } finally {
      _releaseOpLock();
    }
    notifyListeners();
  }

  Future<void> advancedRestore() async {
    if (_operation.running) return;
    final targets = _restoreTargets();
    if (targets.isEmpty) {
      _operation = const OperationState(
        running: false,
        message: 'No injected skins to restore',
      );
      notifyListeners();
      return;
    }
    final game = await EngineService.findGame();
    if (game == null) {
      _operation = const OperationState(
        running: false,
        message: 'Failed: Mobile Legends is not installed',
      );
      notifyListeners();
      return;
    }

    _operation = OperationState(
      running: true,
      message: 'Advanced restore running...',
      total: targets.length,
      stepTotal: _injectStepCount,
    );
    notifyListeners();

    await _acquireOpLock();
    try {
      await EngineService.clearRepairMarkers(game.assetsDir, game.dataDir);
      var failures = 0;
      for (var i = 0; i < targets.length; i++) {
        try {
          await _injectFavorite(targets[i], index: i, count: targets.length);
        } catch (_) {
          failures++;
        }
      }
      _operation = OperationState(
        running: false,
        message: 'Advanced restore completed: '
            '${targets.length - failures} ok, $failures failed',
        done: targets.length - failures,
        total: targets.length,
        step: _injectStepCount,
        stepTotal: _injectStepCount,
        stepLabel: 'Done',
      );
    } finally {
      _releaseOpLock();
    }
    notifyListeners();
  }

  List<Favorite> _restoreTargets() {
    final byHero = <int, Favorite>{};
    for (final entry in _manifest) {
      final match = _favorites.where(
        (f) => f.heroId == entry.heroId && f.skinName == entry.skinName,
      );
      final fav = match.isNotEmpty
          ? match.first
          : Favorite(
              heroName: entry.heroName,
              heroId: entry.heroId,
              skinName: entry.skinName,
              skinImage: entry.skinImage,
              skinSc: entry.skinSc,
            );
      if (fav.skinSc.isEmpty) continue;
      byHero[entry.heroId] = fav;
    }
    if (byHero.isEmpty) {
      for (final fav in _favorites) {
        if (fav.skinSc.isEmpty) continue;
        byHero.putIfAbsent(fav.heroId, () => fav);
      }
    }
    return byHero.values.toList();
  }

  void _recordInjected(InjectedSkin injected) {
    _manifest = _manifest
            .where((m) => m.heroId != injected.heroId)
            .toList() +
        [injected];
    notifyListeners();
    _saveManifest();
  }

  Future<void> _saveManifest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'injected_manifest',
      jsonEncode(_manifest.map((m) => m.toJson()).toList()),
    );
  }

  List<History> get history => _history;

  void _addHistory(Favorite fav) {
    _history = [
      History(
          heroName: fav.heroName,
          skinName: fav.skinName,
          timestamp: DateTime.now().millisecondsSinceEpoch),
      ..._history.where(
          (h) => !(h.heroName == fav.heroName && h.skinName == fav.skinName)),
    ].take(200).toList();
    _saveHistory();
  }

  Future<void> clearHistory() async {
    _history = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'history',
      jsonEncode(_history.map((h) => h.toJson()).toList()),
    );
  }

  String _cosmeticKey(CosmeticCategory category, String title) =>
      '${category.id}|$title';

  Future<void> loadCosmetics(CosmeticCategory category) async {
    if (_cosmetics.containsKey(category)) return;
    await _fetchCosmeticsOf(category);
  }

  Future<void> reloadCosmetics(CosmeticCategory category) async {
    _cosmetics.remove(category);
    await _fetchCosmeticsOf(category);
  }

  Future<void> _fetchCosmeticsOf(CosmeticCategory category) async {
    if (_cosmeticLoading[category] ?? false) return;
    _cosmeticLoading[category] = true;
    _cosmeticError[category] = null;
    notifyListeners();
    try {
      _cosmetics[category] = await _fetchFromApi(category);
    } catch (e) {
      _cosmeticError[category] = e.toString();
    }
    _cosmeticLoading[category] = false;
    notifyListeners();
  }

  Future<List<CosmeticItem>> _fetchFromApi(CosmeticCategory category) =>
      switch (category) {
        CosmeticCategory.newlyAdded => LuminaApi.fetchNewlyAdded(),
        CosmeticCategory.emotes => LuminaApi.fetchEmotes(),
        CosmeticCategory.trails => LuminaApi.fetchTrails(),
        CosmeticCategory.recalls => LuminaApi.fetchRecalls(),
        CosmeticCategory.eliminations => LuminaApi.fetchEliminations(),
        CosmeticCategory.respawns => LuminaApi.fetchRespaws(),
      };

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');

  Future<void> _deleteFile(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  Future<void> injectCosmetic(
      CosmeticCategory category, CosmeticItem item) async {
    if (_operation.running) return;
    if (item.sc.isEmpty) {
      _operation = OperationState(
          running: false,
          message: 'Failed: no download URL for ${item.title}');
      notifyListeners();
      return;
    }
    final game = await EngineService.findGame();
    if (game == null) {
      _operation = OperationState(
          running: false, message: 'Failed: Mobile Legends is not installed');
      notifyListeners();
      return;
    }

    _operation = OperationState(
        running: true, message: 'Injecting ${item.title}...', total: 1);
    notifyListeners();
    try {
      await _acquireOpLock();
      try {
        final cache = await EngineService.cacheDir();
        await cache.create(recursive: true);
        final zip = File(
            '${cache.path}/${category.id}_${_sanitizeFileName(item.title)}.zip');
        if (!zip.existsSync() || zip.lengthSync() == 0) {
          final dl = await EngineService.downloadFile(item.sc, zip.path);
          if (!dl.ok) {
            await _deleteFile(zip);
            throw 'Download failed for ${item.title}'
                '${dl.error != null ? ': ${dl.error}' : ''}';
          }
          if (!zip.existsSync() || zip.lengthSync() == 0) {
            await _deleteFile(zip);
            throw 'Download produced empty file for ${item.title}';
          }
          try {
            final raf = await zip.open();
            final sig = await raf.read(4);
            await raf.close();
            if (!(sig.length == 4 && sig[0] == 0x50 && sig[1] == 0x4B)) {
              await _deleteFile(zip);
              throw 'Downloaded file is not a valid zip for ${item.title}';
            }
          } catch (e) {
            if (e.toString().contains('valid zip')) rethrow;
            await _deleteFile(zip);
            throw 'Invalid zip file for ${item.title}';
          }
        }
        final uz = await EngineService.unzip(zip.path, game.assetsDir);
        if (!uz.ok) {
          await _deleteFile(zip);
          throw 'Extraction failed for ${item.title}'
              '${uz.error != null ? ': ${uz.error}' : ''}';
        }
        _injectedCosmetics = {..._injectedCosmetics, _cosmeticKey(category, item.title)};
        await _saveInjectedCosmetics();
        _operation = OperationState(
            running: false,
            message: 'Injected: ${item.title}',
            done: 1,
            total: 1);
      } finally {
        _releaseOpLock();
      }
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> restoreCosmetic(
      CosmeticCategory category, CosmeticItem item) async {
    final key = _cosmeticKey(category, item.title);
    if (!_injectedCosmetics.contains(key)) return;
    _injectedCosmetics = {..._injectedCosmetics}..remove(key);
    await _saveInjectedCosmetics();
    _operation = OperationState(
        running: false, message: 'Removed injected mark: ${item.title}');
    notifyListeners();
  }

  Future<void> _saveInjectedCosmetics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'injected_cosmetics',
      jsonEncode(
          _injectedCosmetics.map((k) => {'key': k}).toList()),
    );
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}
