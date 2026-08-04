import 'package:flutter_test/flutter_test.dart';
import 'package:yuyu/services/aes_crypto.dart';

void main() {
  test('decrypts AES-256-CBC payload produced by openssl', () {
    const ciphertext = 'WLisa0UCOwAzD8ix8f0CBgP9/coSybElvz+5a3ykSbA=';
    final plain = AesCrypto.decryptBase64(ciphertext);
    expect(plain, 'hello yuyu test payload');
  });

  test('returns null for non-ciphertext payloads', () {
    expect(AesCrypto.decryptBase64('not-encrypted-json'), isNull);
  });
}
