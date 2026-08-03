package com.ryu.vx.data.network

import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * AES-256-CBC / PKCS5Padding used to decrypt the remote data payloads.
 *
 * The key and IV were recovered from the native library (libnative-lib.so) of
 * the original build. They are kept here as build-time constants so the rebuilt
 * app stays compatible with the existing remote data.
 */
object AesCrypto {

    private const val KEY_HEX =
        "4a3f2e1d8c7b6a5f9e0d1c2b3a4f5e6d7c8b9a0e1f2d3c4b5a6f7e8d9c0b1a2f"
    private const val IV_HEX =
        "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d"

    private fun hexToBytes(hex: String): ByteArray {
        require(hex.length % 2 == 0) { "hex string must have even length" }
        return ByteArray(hex.length / 2) { i ->
            hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
    }

    /**
     * Decrypts a base64-encoded AES-CBC ciphertext. Returns null when the
     * payload cannot be decrypted (e.g. it was never encrypted).
     */
    fun decryptBase64(base64Text: String): String? {
        val trimmed = base64Text.trim().replace("\n", "").replace("\r", "")
        return runCatching {
            val cipherText = android.util.Base64.decode(trimmed, android.util.Base64.DEFAULT)
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            val key = SecretKeySpec(hexToBytes(KEY_HEX), "AES")
            val iv = IvParameterSpec(hexToBytes(IV_HEX))
            cipher.init(Cipher.DECRYPT_MODE, key, iv)
            String(cipher.doFinal(cipherText), Charsets.UTF_8)
        }.getOrNull()
    }
}
