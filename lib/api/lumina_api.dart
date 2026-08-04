import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/aes_crypto.dart';

/// Loads and decrypts the remote data hosted on the Cloudflare Pages origin.
/// Every payload is AES-256-CBC encrypted base64 (see [AesCrypto]).
class LuminaApi {
  LuminaApi._();

  static const _base = 'https://luminadata-v2.pages.dev';

  static const _heroes = '/heroes-bytes.txt';
  static const _newlyAdded = '/newly-added-skin-bytes.txt';
  static const _emote = '/emote-bytes.txt';
  static const _trail = '/trail-bytes.txt';
  static const _recall = '/recall-bytes.txt';
  static const _elimination = '/elimination-bytes.txt';
  static const _respawn = '/luminadarespawn-bytes.txt';

  static Future<String> _fetchDecrypted(String endpoint) async {
    final response = await http.get(Uri.parse('$_base$endpoint'));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode} for $endpoint');
    }
    return AesCrypto.decryptBase64(response.body) ?? response.body;
  }

  static Future<List<HeroEntry>> fetchHeroes() async {
    final text = await _fetchDecrypted(_heroes);
    final list = jsonDecode(text) as List;
    return list.map((e) => HeroEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<CosmeticItem>> fetchNewlyAdded() async {
    final text = await _fetchDecrypted(_newlyAdded);
    final list = jsonDecode(text) as List;
    return list.map((e) => CosmeticItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<CosmeticItem>> fetchEmotes() =>
      _fetchCosmetic(_emote);

  static Future<List<CosmeticItem>> fetchTrails() =>
      _fetchCosmetic(_trail);

  static Future<List<CosmeticItem>> fetchRecalls() =>
      _fetchCosmetic(_recall);

  static Future<List<CosmeticItem>> fetchEliminations() =>
      _fetchCosmetic(_elimination);

  static Future<List<CosmeticItem>> fetchRespaws() =>
      _fetchCosmetic(_respawn);

  static Future<List<CosmeticItem>> _fetchCosmetic(String endpoint) async {
    final text = await _fetchDecrypted(endpoint);
    final list = jsonDecode(text) as List;
    return list.map((e) => CosmeticItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
