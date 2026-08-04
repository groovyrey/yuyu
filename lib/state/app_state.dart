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
  final int progress;
  final int done;
  final int total;

  const OperationState({
    this.running = false,
    this.message = '',
    this.progress = 0,
    this.done = 0,
    this.total = 0,
  });

  OperationState copyWith({
    bool? running,
    String? message,
    int? progress,
    int? done,
    int? total,
  }) =>
      OperationState(
        running: running ?? this.running,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        done: done ?? this.done,
        total: total ?? this.total,
      );
}

class AppState extends ChangeNotifier {
  List<HeroEntry> _heroes = [];
  bool _loading = true;
  String? _loadError;

  List<Favorite> _favorites = [];
  List<InjectedSkin> _manifest = [];
  List<History> _history = [];
  Set<String> _injected = {};

  OperationState _operation = const OperationState();
  OperationState get operation => _operation;

  GameTarget? _game;
  bool _storageGranted = false;
  String _shizukuState = 'unavailable';

  StreamSubscription<String>? _resumeSub;

  List<HeroEntry> get heroes => _heroes;
  bool get loading => _loading;
  String? get loadError => _loadError;
  List<Favorite> get favorites => _favorites;
  Set<String> get injected => _injected;
  GameTarget? get game => _game;
  bool get storageGranted => _storageGranted;
  String get shizukuState => _shizukuState;

  bool get isReady {
    if (_game == null || !_storageGranted) return false;
    // Shizuku is required only on Android 11+; the engine falls back to
    // direct access on older versions, so we gate on the bound state lazily
    // from the native side. Bound is the healthy state to show.
    return true;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(prefs);
    notifyListeners();

    _loadHeroes();
    await refreshEnv();
    refreshInjectedStatus();

    // Re-check permissions whenever the user returns from system Settings.
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
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Environment (game detection, storage, shizuku) ────────────────

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
    // Opens the system "All files access" settings page for this app.
    // The actual permission re-check happens automatically via the onResume
    // stream when the user navigates back.
    await EngineService.openStorageSettings();
  }

  // ── Data loading ───────────────────────────────────────────────────

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

  // ── Favorites ──────────────────────────────────────────────────────

  bool isFavorite(int heroId, String skinName) =>
      _favorites.any((f) => f.heroId == heroId && f.skinName == skinName);

  Future<void> addFavorite(HeroEntry hero, String skinName, String image, String sc) async {
    if (isFavorite(hero.heroInfo.id, skinName)) return;
    // One favorite per hero — remove any existing favorite for this hero first.
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

  // ── Injection ──────────────────────────────────────────────────────

  String _safeName(Favorite fav) =>
      '${fav.heroName}-${fav.skinName}'.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');

  Future<File> _cachedZip(Favorite fav) async {
    final cache = await EngineService.cacheDir();
    await cache.create(recursive: true);
    return File('${cache.path}/${_safeName(fav)}.zip');
  }

  Future<void> _injectFavorite(Favorite fav) async {
    if (fav.skinSc.isEmpty) throw 'No download URL for ${fav.skinName}';
    final game = await EngineService.findGame();
    if (game == null) throw 'Mobile Legends is not installed';

    final zip = await _cachedZip(fav);
    if (!zip.existsSync() || zip.lengthSync() == 0) {
      final ok = await EngineService.downloadFile(fav.skinSc, zip.path);
      if (!ok) throw 'Download failed for ${fav.skinName}';
    }

    final ok = await EngineService.unzip(zip.path, game.assetsDir);
    if (!ok) throw 'Extraction failed for ${fav.skinName}';

    final injected = await _buildInjectedSkin(fav, zip, game);
    _recordInjected(injected);
    _addHistory(fav);
  }

  Future<InjectedSkin> _buildInjectedSkin(
      Favorite fav, File zip, GameTarget game) async {
    final entries = await EngineService.hashZipEntries(zip.path);
    if (entries.isEmpty) {
      return InjectedSkin(
        heroName: fav.heroName,
        heroId: fav.heroId,
        skinName: fav.skinName,
        skinImage: fav.skinImage,
        skinSc: fav.skinSc,
      );
    }
    final files = <InjectedFile>[];
    for (final (name, _) in entries) {
      final hashes =
          await EngineService.sha256Files(['${game.assetsDir}/$name']);
      final h = hashes.isNotEmpty ? hashes.first : null;
      if (h != null && h.isNotEmpty) {
        files.add(InjectedFile(path: name, sha256: h));
      }
    }
    return InjectedSkin(
      heroName: fav.heroName,
      heroId: fav.heroId,
      skinName: fav.skinName,
      skinImage: fav.skinImage,
      skinSc: fav.skinSc,
      files: files,
    );
  }

  Future<void> injectSkin(HeroEntry hero, String skinName, String image, String sc) async {
    if (_operation.running) return;
    _operation = OperationState(running: true, message: 'Injecting $skinName...', total: 1);
    notifyListeners();
    try {
      await _injectFavorite(Favorite(
        heroName: hero.heroInfo.name,
        heroId: hero.heroInfo.id,
        skinName: skinName,
        skinImage: image,
        skinSc: sc,
      ));
      _replaceInjectedKey(hero.heroInfo.id, '${hero.heroInfo.id}:$skinName');
      _operation = OperationState(
        running: false,
        message: 'Injected: $skinName',
        done: 1,
        total: 1,
      );
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> injectSkinToSkin(
      HeroEntry hero, String fromSkin, String toSkin, String sc) async {
    if (_operation.running) return;
    final label = '$fromSkin → $toSkin';
    _operation = OperationState(running: true, message: 'Injecting $label...', total: 1);
    notifyListeners();
    try {
      await _injectFavorite(Favorite(
        heroName: hero.heroInfo.name,
        heroId: hero.heroInfo.id,
        skinName: label,
        skinImage: '',
        skinSc: sc,
      ));
      _replaceInjectedKey(hero.heroInfo.id, '${hero.heroInfo.id}:$label');
      _operation = OperationState(
        running: false,
        message: 'Injected: $label',
        done: 1,
        total: 1,
      );
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
    );
    notifyListeners();
    try {
      await _injectFavorite(fav);
      _replaceInjectedKey(fav.heroId, '${fav.heroId}:${fav.skinName}');
      _operation = OperationState(
        running: false,
        message: 'Injected: ${fav.skinName}',
        done: 1,
        total: 1,
      );
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> injectAllFavorites() async {
    if (_operation.running || _favorites.isEmpty) return;
    final list = List<Favorite>.from(_favorites);
    _operation = OperationState(running: true, message: 'Injecting favorites...', total: list.length);
    notifyListeners();

    var done = 0;
    final failures = <String>[];
    for (final fav in list) {
      _operation = _operation.copyWith(
        done: done,
        message: 'Injecting ${fav.skinName}',
        progress: (done * 100) ~/ list.length,
      );
      notifyListeners();
      try {
        await _injectFavorite(fav);
        _replaceInjectedKey(fav.heroId, '${fav.heroId}:${fav.skinName}');
      } catch (e) {
        failures.add('${fav.skinName}: ${_msg(e)}');
      }
      done++;
    }

    final suffix = failures.isNotEmpty ? '\n${failures.take(3).join('\n')}' : '';
    _operation = OperationState(
      running: false,
      message: 'Inject completed: ${list.length - failures.length} ok, ${failures.length} failed$suffix',
      done: list.length - failures.length,
      total: list.length,
    );
    notifyListeners();
  }

  Future<void> advancedRestoreAllFavorites() async {
    if (_operation.running || _favorites.isEmpty) return;
    final list = List<Favorite>.from(_favorites);
    _operation = OperationState(running: true, message: 'Advanced restore running...', total: list.length);
    notifyListeners();

    var done = 0;
    var failures = 0;
    for (final fav in list) {
      _operation = _operation.copyWith(
        done: done,
        message: 'Restoring ${fav.skinName}',
        progress: (done * 100) ~/ list.length,
      );
      notifyListeners();
      try {
        final game = await EngineService.findGame();
        if (game == null) throw 'Mobile Legends is not installed';
        await EngineService.clearRepairMarkers(game.assetsDir, game.dataDir);
        final zip = await _cachedZip(fav);
        if (zip.existsSync() && fav.skinSc.isNotEmpty) {
          await EngineService.unzip(zip.path, game.assetsDir);
        }
        _addHistory(fav);
      } catch (_) {
        failures++;
      }
      done++;
    }

    _operation = OperationState(
      running: false,
      message: 'Advanced restore completed: ${list.length - failures} ok, $failures failed',
      done: list.length - failures,
      total: list.length,
    );
    notifyListeners();
  }

  // ── Injected checker ───────────────────────────────────────────────

  Future<void> refreshInjectedStatus() async {
    _injected = {};
    notifyListeners();
    final game = await EngineService.findGame();
    if (game == null) return;

    var manifest = List<InjectedSkin>.from(_manifest);
    var backfilled = false;
    for (var i = 0; i < manifest.length; i++) {
      if (manifest[i].files.isNotEmpty) continue;
      final rebuilt = await _backfillInjectedSkin(manifest[i]);
      if (rebuilt != null) {
        manifest[i] = rebuilt;
        backfilled = true;
      }
    }
    if (backfilled) {
      _manifest = manifest;
      await _saveManifest();
    }

    final result = <String>{};
    for (final entry in manifest) {
      if (entry.files.isEmpty) continue;
      final paths = entry.files.map((f) => '${game.assetsDir}/${f.path}').toList();
      final hashes = await EngineService.sha256Files(paths);
      var allMatch = true;
      for (var i = 0; i < entry.files.length; i++) {
        final current = i < hashes.length ? hashes[i] : null;
        if (current == null ||
            current.isEmpty ||
            current.toLowerCase() != entry.files[i].sha256.toLowerCase()) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) result.add('${entry.heroId}:${entry.skinName}');
    }
    _injected = result;
    notifyListeners();
  }

  Future<InjectedSkin?> _backfillInjectedSkin(InjectedSkin entry) async {
    final zip = await _cachedZip(Favorite(
      heroName: entry.heroName,
      skinName: entry.skinName,
    ));
    if (!zip.existsSync()) return null;
    final entries = await EngineService.hashZipEntries(zip.path);
    if (entries.isEmpty) return null;
    return InjectedSkin(
      heroName: entry.heroName,
      heroId: entry.heroId,
      skinName: entry.skinName,
      skinImage: entry.skinImage,
      skinSc: entry.skinSc,
      files: entries
          .map((e) => InjectedFile(path: e.$1, sha256: e.$2))
          .toList(),
    );
  }

  void _recordInjected(InjectedSkin injected) {
    // One skin per hero — evict any previously recorded skin for this hero.
    _manifest = _manifest
            .where((m) => m.heroId != injected.heroId)
            .toList() +
        [injected];
    _saveManifest();
  }

  /// Removes all in-memory injected keys for the given [heroId] and adds the
  /// new [key]. Enforces the one-active-skin-per-hero rule in the UI.
  void _replaceInjectedKey(int heroId, String key) {
    _injected = {
      ..._injected.where((k) => !k.startsWith('$heroId:')),
      key,
    };
  }

  Future<void> _saveManifest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'injected_manifest',
      jsonEncode(_manifest.map((m) => m.toJson()).toList()),
    );
  }

  // ── History ────────────────────────────────────────────────────────

  List<History> get history => _history;

  void _addHistory(Favorite fav) {
    _history = [
      History(heroName: fav.heroName, skinName: fav.skinName, timestamp: DateTime.now().millisecondsSinceEpoch),
      ..._history.where((h) => !(h.heroName == fav.heroName && h.skinName == fav.skinName)),
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

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}
