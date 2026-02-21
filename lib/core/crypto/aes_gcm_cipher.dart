import 'dart:typed_data';

import 'package:securityexperts_app/core/crypto/crypto_provider.dart';

/// AES-256-GCM authenticated encryption cipher.
///
/// Wraps [CryptoProvider] for convenient AES-256-GCM operations.
/// Used for both message encryption (via Double Ratchet message keys)
/// and media file encryption (via random per-file keys).
class AesGcmCipher {
  final CryptoProvider _crypto;

  const AesGcmCipher(this._crypto);

  /// Encrypt plaintext with AES-256-GCM.
  ///
  /// [key] must be exactly 32 bytes.
  /// [iv] must be exactly 12 bytes.
  /// Returns ciphertext with appended 16-byte authentication tag.
  Future<Uint8List> encrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List plaintext,
    Uint8List? aad,
  }) async {
    _validateKey(key);
    _validateIv(iv);

    return _crypto.aesGcmEncrypt(
      key: key,
      iv: iv,
      plaintext: plaintext,
      aad: aad,
    );
  }

  /// Decrypt AES-256-GCM ciphertext.
  ///
  /// [key] must be exactly 32 bytes.
  /// [iv] must be exactly 12 bytes.
  /// [ciphertext] must include the 16-byte appended authentication tag.
  /// Throws if authentication fails (tampered ciphertext).
  Future<Uint8List> decrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
    Uint8List? aad,
  }) async {
    _validateKey(key);
    _validateIv(iv);

    if (ciphertext.length < 16) {
      throw ArgumentError(
        'Ciphertext too short: must include 16-byte GCM authentication tag',
      );
    }

    return _crypto.aesGcmDecrypt(
      key: key,
      iv: iv,
      ciphertext: ciphertext,
      aad: aad,
    );
  }

  void _validateKey(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 key must be exactly 32 bytes, got ${key.length}');
    }
  }

  void _validateIv(Uint8List iv) {
    if (iv.length != 12) {
      throw ArgumentError('GCM IV must be exactly 12 bytes, got ${iv.length}');
    }
  }
}
