import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/api.dart';

/// AES-256-CBC / PKCS7 used to decrypt the remote data payloads. The key and
/// IV match the ones embedded in the original Android build so the Flutter
/// app stays compatible with the existing remote data.
class AesCrypto {
  AesCrypto._();

  static final Uint8List _key = _hexToBytes(
      '4a3f2e1d8c7b6a5f9e0d1c2b3a4f5e6d7c8b9a0e1f2d3c4b5a6f7e8d9c0b1a2f');
  static final Uint8List _iv =
      _hexToBytes('1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d');

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  /// Decrypts a base64 AES-CBC ciphertext, or returns null when the payload
  /// cannot be decrypted (e.g. it was never encrypted).
  static String? decryptBase64(String base64Text) {
    try {
      final trimmed = base64Text.trim().replaceAll(RegExp(r'[\r\n]'), '');
      final data = base64.decode(trimmed);

      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      )..init(
          false,
          PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
            ParametersWithIV<KeyParameter>(KeyParameter(_key), _iv),
            null,
          ),
        );

      final output = cipher.process(data);
      return utf8.decode(output);
    } catch (_) {
      return null;
    }
  }
}
