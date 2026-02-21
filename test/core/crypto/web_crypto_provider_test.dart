import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/web_crypto_provider.dart';

void main() {
  late WebCryptoProvider crypto;

  setUp(() {
    crypto = WebCryptoProvider();
  });

  // ===========================================================================
  // X25519 Key Exchange
  // ===========================================================================

  group('WebCryptoProvider - X25519', () {
    test('should generate valid X25519 key pair', () async {
      final keyPair = await crypto.generateX25519KeyPair();

      expect(keyPair.publicKey.length, 32);
      expect(keyPair.privateKey.length, 32);
    });

    test('should generate unique key pairs', () async {
      final kp1 = await crypto.generateX25519KeyPair();
      final kp2 = await crypto.generateX25519KeyPair();

      expect(kp1.publicKey, isNot(equals(kp2.publicKey)));
    });

    test('should produce matching shared secrets (DH)', () async {
      final alice = await crypto.generateX25519KeyPair();
      final bob = await crypto.generateX25519KeyPair();

      final sharedAlice =
          await crypto.x25519Dh(alice.privateKey, bob.publicKey);
      final sharedBob =
          await crypto.x25519Dh(bob.privateKey, alice.publicKey);

      expect(sharedAlice.length, 32);
      expect(sharedAlice, equals(sharedBob));
    });
  });

  // ===========================================================================
  // Ed25519 Signatures
  // ===========================================================================

  group('WebCryptoProvider - Ed25519', () {
    test('should generate valid Ed25519 key pair', () async {
      final keyPair = await crypto.generateEd25519KeyPair();

      expect(keyPair.publicKey.length, 32);
      expect(keyPair.privateKey.length, 32);
    });

    test('should sign and verify', () async {
      final keyPair = await crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList([1, 2, 3, 4, 5]);

      final signature = await crypto.ed25519Sign(
        keyPair.privateKey,
        message,
      );

      expect(signature.length, 64);

      final valid = await crypto.ed25519Verify(
        keyPair.publicKey,
        message,
        signature,
      );
      expect(valid, true);
    });

    test('should reject tampered message', () async {
      final keyPair = await crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList([1, 2, 3]);
      final tamperedMessage = Uint8List.fromList([1, 2, 4]);

      final signature = await crypto.ed25519Sign(
        keyPair.privateKey,
        message,
      );

      final valid = await crypto.ed25519Verify(
        keyPair.publicKey,
        tamperedMessage,
        signature,
      );
      expect(valid, false);
    });
  });

  // ===========================================================================
  // AES-256-GCM
  // ===========================================================================

  group('WebCryptoProvider - AES-256-GCM', () {
    test('should encrypt and decrypt', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList([72, 101, 108, 108, 111]); // Hello

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      // Ciphertext should be plaintext.length + 16 (GCM tag)
      expect(ciphertext.length, plaintext.length + 16);

      final decrypted = await crypto.aesGcmDecrypt(
        key: key,
        iv: iv,
        ciphertext: ciphertext,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should fail decryption with wrong key', () async {
      final key1 = crypto.secureRandomBytes(32);
      final key2 = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList([1, 2, 3]);

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key1,
        iv: iv,
        plaintext: plaintext,
      );

      expect(
        () => crypto.aesGcmDecrypt(key: key2, iv: iv, ciphertext: ciphertext),
        throwsA(anything),
      );
    });
  });

  // ===========================================================================
  // HKDF
  // ===========================================================================

  group('WebCryptoProvider - HKDF', () {
    test('should derive deterministic key', () async {
      final ikm = crypto.secureRandomBytes(32);
      final salt = crypto.secureRandomBytes(32);
      final info = Uint8List.fromList([1, 2, 3]);

      final derived1 = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info,
        outputLength: 32,
      );

      final derived2 = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info,
        outputLength: 32,
      );

      expect(derived1.length, 32);
      expect(derived1, equals(derived2));
    });
  });

  // ===========================================================================
  // HMAC
  // ===========================================================================

  group('WebCryptoProvider - HMAC-SHA-256', () {
    test('should compute deterministic HMAC', () async {
      final key = crypto.secureRandomBytes(32);
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final mac1 = await crypto.hmacSha256(key, data);
      final mac2 = await crypto.hmacSha256(key, data);

      expect(mac1.length, 32);
      expect(mac1, equals(mac2));
    });

    test('should produce different MACs for different data', () async {
      final key = crypto.secureRandomBytes(32);
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([4, 5, 6]);

      final mac1 = await crypto.hmacSha256(key, data1);
      final mac2 = await crypto.hmacSha256(key, data2);

      expect(mac1, isNot(equals(mac2)));
    });
  });

  // ===========================================================================
  // Secure Random
  // ===========================================================================

  group('WebCryptoProvider - secureRandomBytes', () {
    test('should generate bytes of requested length', () {
      expect(crypto.secureRandomBytes(16).length, 16);
      expect(crypto.secureRandomBytes(32).length, 32);
      expect(crypto.secureRandomBytes(64).length, 64);
    });

    test('should generate different bytes each time', () {
      final a = crypto.secureRandomBytes(32);
      final b = crypto.secureRandomBytes(32);
      expect(a, isNot(equals(b)));
    });
  });

  // ===========================================================================
  // Cross-Platform Compatibility
  // ===========================================================================

  group('WebCryptoProvider - Cross-Platform Compatibility', () {
    test('web and native providers should produce compatible DH', () async {
      // Both providers use X25519 — shared secrets should match
      // even when keys are generated by different providers.
      // This test verifies within WebCryptoProvider; cross-provider
      // testing requires integration test with NativeCryptoProvider.
      final alice = await crypto.generateX25519KeyPair();
      final bob = await crypto.generateX25519KeyPair();

      final shared1 = await crypto.x25519Dh(alice.privateKey, bob.publicKey);
      final shared2 = await crypto.x25519Dh(bob.privateKey, alice.publicKey);

      expect(shared1, equals(shared2));
    });

    test('AES-GCM format is consistent (ciphertext ‖ 16-byte tag)', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(List.generate(100, (i) => i));

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      // ciphertext = actual_ciphertext (100 bytes) + GCM_tag (16 bytes)
      expect(ciphertext.length, 116);
    });
  });
}
