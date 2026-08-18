import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class DownloadResult {
  final bool ok;
  final String? error;

  const DownloadResult({required this.ok, this.error});
}

class EngineService {
  EngineService._();

  static const _channel = MethodChannel('com.ryu.vx/engine');
  static const _lifecycleChannel = EventChannel('com.ryu.vx/lifecycle');

  static Stream<String> get onResume => _lifecycleChannel
      .receiveBroadcastStream()
      .map((e) => e as String);

  static Future<GameTarget?> findGame() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('findGame');
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

  static Future<DownloadResult> downloadFile(String url, String path) async {
    try {
      final result = await _channel
          .invokeMethod<bool>('downloadFile', {'url': url, 'path': path});
      if (result == true) {
        return const DownloadResult(ok: true);
      }
      return const DownloadResult(ok: false, error: 'Native download returned false');
    } on PlatformException catch (e) {
      return DownloadResult(ok: false, error: e.message);
    }
  }

  static Future<DownloadResult> unzip(String source, String target) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'unzip',
        {'source': source, 'target': target},
      );
      if (result == true) {
        return const DownloadResult(ok: true);
      }
      return const DownloadResult(ok: false, error: 'Native unzip returned false');
    } on PlatformException catch (e) {
      return DownloadResult(ok: false, error: e.message);
    }
  }

  static Future<bool> deleteFolder(String path) async {
    final result = await _channel.invokeMethod<bool>(
      'deleteFolder',
      {'path': path},
    );
    return result ?? false;
  }

  static Future<List<String?>> sha256Files(List<String> paths) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
        'sha256Files', {'paths': paths});
    return result?.map((e) => e as String?).toList() ?? [];
  }

  static Future<List<(String, String)>> hashZipEntries(String path) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'hashZipEntries',
      {'path': path},
    );
    return (result ?? const []).map((e) {
      final pair = e as List<dynamic>;
      return (pair[0] as String, pair[1] as String);
    }).toList();
  }

  static Future<void> clearRepairMarkers(
      String assetsDir, String dataDir) async {
    await _channel.invokeMethod<void>(
      'clearRepairMarkers',
      {'assetsDir': assetsDir, 'dataDir': dataDir},
    );
  }

  static Future<Directory> cacheDir() async {
    final base = await getExternalStorageDirectory();
    return Directory(
        '${base?.path ?? '/storage/emulated/0/Android/data/com.ryu.vx/files'}/skin_cache');
  }
}
