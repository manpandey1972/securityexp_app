import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';

void main() {
  late NativeCryptoProvider crypto;

  setUp(() {
    crypto = NativeCryptoProvider();
  });

  // ===========================================================================
  // X25519 Key Exchange
  // ===========================================================================

  group('X25519 Key Generation', () {
    test('should generate valid X25519 key pair', () async {
      final keyPair = await crypto.generateX25519KeyPair();

      expect(keyPair.publicKey.length, 32);
      expect(keyPair.privateKey.length, 32);
    });

    test('should generate unique key pairs each time', () async {
      final kp1 = await crypto.generateX25519KeyPair();
      final kp2 = await crypto.generateX25519KeyPair();

      expect(kp1.publicKey, isNot(equals(kp2.publicKey)));
      expect(kp1.privateKey, isNot(equals(kp2.privateKey)));
    });

    test('should produce non-zero keys', () async {
      final keyPair = await crypto.generateX25519KeyPair();

      final allZeroPublic = keyPair.publicKey.every((b) => b == 0);
      final allZeroPrivate = keyPair.privateKey.every((b) => b == 0);

      expect(allZeroPublic, false);
      expect(allZeroPrivate, false);
    });
  });

  group('X25519 Diffie-Hellman', () {
    test('should produce shared secret via ECDH', () async {
      final alice = await crypto.generateX25519KeyPair();
      final bob = await crypto.generateX25519KeyPair();

      final sharedAlice =
          await crypto.x25519Dh(alice.privateKey, bob.publicKey);
      final sharedBob =
          await crypto.x25519Dh(bob.privateKey, alice.publicKey);

      expect(sharedAlice.length, 32);
      expect(sharedAlice, equals(sharedBob));
    });

    test('should produce different secrets with different peers', () async {
      final alice = await crypto.generateX25519KeyPair();
      final bob = await crypto.generateX25519KeyPair();
      final carol = await crypto.generateX25519KeyPair();

      final sharedAB =
          await crypto.x25519Dh(alice.privateKey, bob.publicKey);
      final sharedAC =
          await crypto.x25519Dh(alice.privateKey, carol.publicKey);

      expect(sharedAB, isNot(equals(sharedAC)));
    });
  });

  // ===========================================================================
  // Ed25519 Signatures
  // ===========================================================================

  group('Ed25519 Key Generation', () {
    test('should generate valid Ed25519 key pair', () async {
      final keyPair = await crypto.generateEd25519KeyPair();

      expect(keyPair.publicKey.length, 32);
      // Ed25519 private key seed is 32 bytes
      expect(keyPair.privateKey.length, 32);
    });
  });

  group('Ed25519 Signing and Verification', () {
    test('should sign and verify a message', () async {
      final keyPair = await crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList(utf8.encode('Hello, Signal!'));

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

    test('should fail verification with wrong message', () async {
      final keyPair = await crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList(utf8.encode('Original'));
      final tampered = Uint8List.fromList(utf8.encode('Tampered'));

      final signature = await crypto.ed25519Sign(
        keyPair.privateKey,
        message,
      );

      final valid = await crypto.ed25519Verify(
        keyPair.publicKey,
        tampered,
        signature,
      );
      expect(valid, false);
    });

    test('should fail verification with wrong key', () async {
      final keyPair1 = await crypto.generateEd25519KeyPair();
      final keyPair2 = await crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList(utf8.encode('Test'));

      final signature = await crypto.ed25519Sign(
        keyPair1.privateKey,
        message,
      );

      final valid = await crypto.ed25519Verify(
        keyPair2.publicKey,
        message,
        signature,
      );
      expect(valid, false);
    });

    test('should produce deterministic signatures', () async {
      final keyPair = await crypto.generateEd25519KeyPair();
      final message = Uint8List.fromList(utf8.encode('Deterministic'));

      final sig1 = await crypto.ed25519Sign(keyPair.privateKey, message);
      final sig2 = await crypto.ed25519Sign(keyPair.privateKey, message);

      expect(sig1, equals(sig2));
    });

    test('should sign empty message', () async {
      final keyPair = await crypto.generateEd25519KeyPair();
      final message = Uint8List(0);

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
  });

  // ===========================================================================
  // AES-256-GCM
  // ===========================================================================

  group('AES-256-GCM Encryption', () {
    test('should encrypt and decrypt plaintext', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(
        utf8.encode('Secret message for E2EE chat'),
      );

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

    test('should encrypt and decrypt with AAD', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('With AAD'));
      final aad = Uint8List.fromList(utf8.encode('header data'));

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
        aad: aad,
      );

      final decrypted = await crypto.aesGcmDecrypt(
        key: key,
        iv: iv,
        ciphertext: ciphertext,
        aad: aad,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should fail decryption with wrong key', () async {
      final key1 = crypto.secureRandomBytes(32);
      final key2 = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));

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

    test('should fail decryption with wrong AAD', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('AAD test'));
      final aad1 = Uint8List.fromList(utf8.encode('correct'));
      final aad2 = Uint8List.fromList(utf8.encode('tampered'));

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
        aad: aad1,
      );

      expect(
        () => crypto.aesGcmDecrypt(
          key: key,
          iv: iv,
          ciphertext: ciphertext,
          aad: aad2,
        ),
        throwsA(anything),
      );
    });

    test('should produce different ciphertext with different IVs', () async {
      final key = crypto.secureRandomBytes(32);
      final iv1 = crypto.secureRandomBytes(12);
      final iv2 = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('Same plaintext'));

      final ct1 = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv1,
        plaintext: plaintext,
      );
      final ct2 = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv2,
        plaintext: plaintext,
      );

      expect(ct1, isNot(equals(ct2)));
    });

    test('should handle empty plaintext', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List(0);

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      // Empty plaintext → only 16-byte GCM tag
      expect(ciphertext.length, 16);

      final decrypted = await crypto.aesGcmDecrypt(
        key: key,
        iv: iv,
        ciphertext: ciphertext,
      );
      expect(decrypted.length, 0);
    });

    test('should handle large plaintext (1 MB)', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = crypto.secureRandomBytes(1024 * 1024);

      final ciphertext = await crypto.aesGcmEncrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      final decrypted = await crypto.aesGcmDecrypt(
        key: key,
        iv: iv,
        ciphertext: ciphertext,
      );

      expect(decrypted, equals(plaintext));
    });
  });

  // ===========================================================================
  // HKDF-SHA-256
  // ===========================================================================

  group('HKDF-SHA-256', () {
    test('should derive output of requested length', () async {
      final ikm = crypto.secureRandomBytes(32);
      final salt = crypto.secureRandomBytes(32);
      final info = Uint8List.fromList(utf8.encode('test'));

      final output = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info,
        outputLength: 64,
      );

      expect(output.length, 64);
    });

    test('should produce deterministic output', () async {
      final ikm = Uint8List.fromList(List.generate(32, (i) => i));
      final salt = Uint8List.fromList(List.generate(32, (i) => i + 32));
      final info = Uint8List.fromList(utf8.encode('deterministic'));

      final out1 = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info,
        outputLength: 32,
      );
      final out2 = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info,
        outputLength: 32,
      );

      expect(out1, equals(out2));
    });

    test('should produce different output for different info', () async {
      final ikm = crypto.secureRandomBytes(32);
      final salt = crypto.secureRandomBytes(32);
      final info1 = Uint8List.fromList(utf8.encode('info1'));
      final info2 = Uint8List.fromList(utf8.encode('info2'));

      final out1 = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info1,
        outputLength: 32,
      );
      final out2 = await crypto.hkdfDerive(
        inputKeyMaterial: ikm,
        salt: salt,
        info: info2,
        outputLength: 32,
      );

      expect(out1, isNot(equals(out2)));
    });
  });

  // ===========================================================================
  // HMAC-SHA-256
  // ===========================================================================

  group('HMAC-SHA-256', () {
    test('should produce 32-byte MAC', () async {
      final key = crypto.secureRandomBytes(32);
      final data = Uint8List.fromList(utf8.encode('HMAC test'));

      final mac = await crypto.hmacSha256(key, data);
      expect(mac.length, 32);
    });

    test('should produce deterministic MAC', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList(utf8.encode('deterministic'));

      final mac1 = await crypto.hmacSha256(key, data);
      final mac2 = await crypto.hmacSha256(key, data);

      expect(mac1, equals(mac2));
    });

    test('should produce different MAC for different data', () async {
      final key = crypto.secureRandomBytes(32);
      final data1 = Uint8List.fromList([0x01]);
      final data2 = Uint8List.fromList([0x02]);

      final mac1 = await crypto.hmacSha256(key, data1);
      final mac2 = await crypto.hmacSha256(key, data2);

      expect(mac1, isNot(equals(mac2)));
    });
  });

  // ===========================================================================
  // Secure Random
  // ===========================================================================

  group('secureRandomBytes', () {
    test('should generate requested length', () async {
      final bytes = crypto.secureRandomBytes(64);
      expect(bytes.length, 64);
    });

    test('should generate unique bytes', () async {
      final bytes1 = crypto.secureRandomBytes(32);
      final bytes2 = crypto.secureRandomBytes(32);
      // Probability of collision is 2^(-256), effectively zero
      expect(bytes1, isNot(equals(bytes2)));
    });
  });
}
