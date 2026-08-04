import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Method-channel bridge to the native Android engine (Shizuku, file access,
/// downloads). All UI and business logic live in Dart; only the operations
/// that need Android APIs are delegated here.
class EngineService {
  EngineService._();

  static const _channel = MethodChannel('com.ryu.vx/engine');
  static const _lifecycleChannel = EventChannel('com.ryu.vx/lifecycle');

  /// Emits `"resume"` every time the Android Activity comes to the foreground.
  static Stream<String> get onResume => _lifecycleChannel
      .receiveBroadcastStream()
      .map((e) => e as String);

  static Future<GameTarget?> findGame() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('findGame');
    return result == null ? null : GameTarget.fromMap(result);
  }

  static Future<bool> storageGranted() async {
    final result = await _channel.invokeMethod<bool>('storageGranted');
    return result ?? false;
  }

  static Future<void> openStorageSettings() async {
    await _channel.invokeMethod<void>('openStorageSettings');
  }

  static Future<String> shizukuState() async {
    final result = await _channel.invokeMethod<String>('shizukuState');
    return result ?? 'unavailable';
  }

  static Future<void> requestShizukuPermission() async {
    await _channel.invokeMethod<void>('requestShizukuPermission');
  }

  static Future<void> bindShizuku() async {
    await _channel.invokeMethod<void>('bindShizuku');
  }

  static Future<bool> downloadFile(String url, String path) async {
    final result = await _channel
        .invokeMethod<bool>('downloadFile', {'url': url, 'path': path});
    return result ?? false;
  }

  static Future<bool> unzip(String source, String target) async {
    final result = await _channel.invokeMethod<bool>(
      'unzip',
      {'source': source, 'target': target},
    );
    return result ?? false;
  }

  static Future<bool> deleteFolder(String path) async {
    final result = await _channel.invokeMethod<bool>(
      'deleteFolder',
      {'path': path},
    );
    return result ?? false;
  }

  static Future<List<String?>> sha256Files(List<String> paths) async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('sha256Files', {'paths': paths});
    return result?.map((e) => e as String?).toList() ?? [];
  }

  /// SHA-256 of each zip entry, computed from the zip's own bytes. Used to
  /// backfill the injected manifest for entries recorded before hashes.
  static Future<List<(String, String)>> hashZipEntries(String path) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'hashZipEntries',
      {'path': path},
    );
    return (result ?? const [])
        .map((e) {
          final pair = e as List<dynamic>;
          return (pair[0] as String, pair[1] as String);
        })
        .toList();
  }

  static Future<void> clearRepairMarkers(String assetsDir, String dataDir) async {
    await _channel.invokeMethod<void>(
      'clearRepairMarkers',
      {'assetsDir': assetsDir, 'dataDir': dataDir},
    );
  }

  /// App-owned external cache dir (files/skin_cache). No permission needed.
  static Future<Directory> cacheDir() async {
    final base = await getExternalStorageDirectory();
    return Directory('${base?.path ?? '/storage/emulated/0/Android/data/com.ryu.vx/files'}/skin_cache');
  }
}
