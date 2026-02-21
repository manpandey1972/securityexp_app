import 'dart:typed_data';

/// Key pair containing public and private key material.
class CryptoKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  const CryptoKeyPair({
    required this.publicKey,
    required this.privateKey,
  });
}

/// Platform-agnostic crypto interface.
///
/// Mobile and web each provide their own implementation.
/// Mobile: [NativeCryptoProvider] — uses `cryptography` Dart package
///   (delegates to CommonCrypto on iOS, BoringSSL on Android via FFI).
/// Web: WebCryptoProvider — uses libsodium.js WASM + Web Crypto API.
abstract class CryptoProvider {
  /// X25519 key pair generation.
  Future<CryptoKeyPair> generateX25519KeyPair();

  /// X25519 Diffie-Hellman key agreement.
  /// Returns the 32-byte shared secret.
  Future<Uint8List> x25519Dh(Uint8List privateKey, Uint8List publicKey);

  /// Ed25519 key pair generation.
  Future<CryptoKeyPair> generateEd25519KeyPair();

  /// Ed25519 signing.
  /// Returns the 64-byte signature.
  Future<Uint8List> ed25519Sign(Uint8List privateKey, Uint8List message);

  /// Ed25519 signature verification.
  Future<bool> ed25519Verify(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  );

  /// AES-256-GCM encrypt.
  /// Returns ciphertext with appended 16-byte GCM authentication tag.
  Future<Uint8List> aesGcmEncrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List plaintext,
    Uint8List? aad,
  });

  /// AES-256-GCM decrypt.
  /// Expects ciphertext with appended 16-byte GCM authentication tag.
  Future<Uint8List> aesGcmDecrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
    Uint8List? aad,
  });

  /// HKDF-SHA-256 key derivation.
  Future<Uint8List> hkdfDerive({
    required Uint8List inputKeyMaterial,
    required Uint8List salt,
    required Uint8List info,
    required int outputLength,
  });

  /// HMAC-SHA-256 computation.
  Future<Uint8List> hmacSha256(Uint8List key, Uint8List data);

  /// Cryptographically secure random bytes.
  Uint8List secureRandomBytes(int length);
}
