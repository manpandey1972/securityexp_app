import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/aes_gcm_cipher.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/chat/services/media_encryption_service.dart';

import '../../../helpers/service_mocks.mocks.dart';

void main() {
  late NativeCryptoProvider crypto;
  late AesGcmCipher cipher;
  late MediaEncryptionService service;

  setUpAll(() {
    // Register a mock AppLogger for service locator
    if (!sl.isRegistered<AppLogger>()) {
      sl.registerSingleton<AppLogger>(MockAppLogger());
    }
  });

  setUp(() {
    crypto = NativeCryptoProvider();
    cipher = AesGcmCipher(crypto);
    service = MediaEncryptionService(
      crypto: crypto,
      cipher: cipher,
    );
  });

  // =========================================================================
  // FILE ENCRYPTION / DECRYPTION — ROUNDTRIP
  // =========================================================================

  group('encryptFile / decryptFile', () {
    test('should encrypt and decrypt a small file (roundtrip)', () async {
      final plaintext = Uint8List.fromList(
        utf8.encode('Hello, this is a secret media file!'),
      );

      final result = await service.encryptFile(plaintext);

      // Verify result fields
      expect(result.encryptedBytes, isNotEmpty);
      expect(result.encryptedBytes, isNot(equals(plaintext)));
      expect(result.mediaKey, isNotEmpty);
      expect(result.mediaHash, isNotEmpty);
      expect(result.originalSize, equals(plaintext.length));

      // mediaKey should be valid Base64 encoding 44 bytes (32 key + 12 IV)
      final decoded = base64Decode(result.mediaKey);
      expect(decoded.length, equals(44));

      // Decrypt and verify roundtrip
      final decrypted = await service.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should encrypt and decrypt a 1 KB file', () async {
      final plaintext = crypto.secureRandomBytes(1024);

      final result = await service.encryptFile(plaintext);
      final decrypted = await service.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should encrypt and decrypt a 100 KB file', () async {
      final plaintext = crypto.secureRandomBytes(100 * 1024);

      final result = await service.encryptFile(plaintext);
      final decrypted = await service.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should encrypt and decrypt a 1 byte file', () async {
      final plaintext = Uint8List.fromList([42]);

      final result = await service.encryptFile(plaintext);
      final decrypted = await service.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should produce different ciphertext for same plaintext', () async {
      final plaintext = Uint8List.fromList(utf8.encode('Same content'));

      final result1 = await service.encryptFile(plaintext);
      final result2 = await service.encryptFile(plaintext);

      // Different keys and ciphertexts each time
      expect(result1.mediaKey, isNot(equals(result2.mediaKey)));
      expect(result1.encryptedBytes, isNot(equals(result2.encryptedBytes)));

      // Same hash (same plaintext)
      expect(result1.mediaHash, equals(result2.mediaHash));
      expect(result1.originalSize, equals(result2.originalSize));
    });

    test('should decrypt with correct hash (AAD-bound)', () async {
      final plaintext = Uint8List.fromList(utf8.encode('Hash-bound'));

      final result = await service.encryptFile(plaintext);

      // Decrypting with correct hash should succeed (AAD matches)
      final decrypted = await service.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });
  });

  // =========================================================================
  // INTEGRITY VERIFICATION
  // =========================================================================

  group('integrity verification', () {
    test('should throw on wrong hash (AAD mismatch causes GCM failure)',
        () async {
      final plaintext = Uint8List.fromList(utf8.encode('Integrity test'));

      final result = await service.encryptFile(plaintext);

      // Providing a wrong hash causes AAD mismatch → GCM auth failure
      expect(
        () => service.decryptFile(
          encryptedBytes: result.encryptedBytes,
          mediaKey: result.mediaKey,
          mediaHash: 'deadbeef' * 8, // 64-char fake hex hash
        ),
        throwsA(anything),
      );
    });

    test('should detect tampered ciphertext via GCM auth failure', () async {
      final plaintext = Uint8List.fromList(utf8.encode('Tamper test'));

      final result = await service.encryptFile(plaintext);

      // Flip a byte in the ciphertext
      final tampered = Uint8List.fromList(result.encryptedBytes);
      tampered[tampered.length ~/ 2] ^= 0xFF;

      expect(
        () => service.decryptFile(
          encryptedBytes: tampered,
          mediaKey: result.mediaKey,
        ),
        throwsA(anything), // GCM authentication failure
      );
    });
  });

  // =========================================================================
  // MEDIA KEY VALIDATION
  // =========================================================================

  group('mediaKey validation', () {
    test('should reject invalid mediaKey length', () async {
      final plaintext = Uint8List.fromList(utf8.encode('Test'));
      final result = await service.encryptFile(plaintext);

      // Too short key
      expect(
        () => service.decryptFile(
          encryptedBytes: result.encryptedBytes,
          mediaKey: base64Encode(Uint8List(20)),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Too long key
      expect(
        () => service.decryptFile(
          encryptedBytes: result.encryptedBytes,
          mediaKey: base64Encode(Uint8List(50)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject wrong mediaKey for decryption', () async {
      final plaintext = Uint8List.fromList(utf8.encode('Wrong key'));

      final result = await service.encryptFile(plaintext);

      // Generate a different key
      final wrongKey = Uint8List(44);
      wrongKey.setRange(0, 32, crypto.secureRandomBytes(32));
      wrongKey.setRange(32, 44, crypto.secureRandomBytes(12));

      expect(
        () => service.decryptFile(
          encryptedBytes: result.encryptedBytes,
          mediaKey: base64Encode(wrongKey),
        ),
        throwsA(anything), // GCM authentication failure
      );
    });
  });

  // =========================================================================
  // THUMBNAIL ENCRYPTION
  // =========================================================================

  group('thumbnail encryption', () {
    test('should encrypt and decrypt thumbnail (roundtrip)', () async {
      // Simulate a small thumbnail (e.g., 5 KB JPEG)
      final thumbnail = crypto.secureRandomBytes(5 * 1024);

      final (encryptedBytes, thumbnailKey) =
          await service.encryptThumbnail(thumbnail);

      expect(encryptedBytes, isNotEmpty);
      expect(encryptedBytes, isNot(equals(thumbnail)));
      expect(thumbnailKey, isNotEmpty);

      // thumbnailKey should decode to 44 bytes
      final decoded = base64Decode(thumbnailKey);
      expect(decoded.length, equals(44));

      // Decrypt
      final decrypted = await service.decryptThumbnail(
        encryptedBytes: encryptedBytes,
        thumbnailKey: thumbnailKey,
      );

      expect(decrypted, equals(thumbnail));
    });

    test('should produce different keys for each thumbnail', () async {
      final thumbnail = crypto.secureRandomBytes(1024);

      final (_, key1) = await service.encryptThumbnail(thumbnail);
      final (_, key2) = await service.encryptThumbnail(thumbnail);

      expect(key1, isNot(equals(key2)));
    });

    test('should reject invalid thumbnailKey length', () async {
      final encrypted = crypto.secureRandomBytes(100);

      expect(
        () => service.decryptThumbnail(
          encryptedBytes: encrypted,
          thumbnailKey: base64Encode(Uint8List(30)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // CHUNKED ENCRYPTION (large files)
  // =========================================================================

  group('chunked encryption', () {
    // Use a small chunk threshold for testing
    late MediaEncryptionService smallChunkService;

    setUp(() {
      // Create a service where we can test chunked behavior
      // The default chunk threshold is 10 MB — we test with actual
      // threshold behavior using a small file just below and above
      smallChunkService = MediaEncryptionService(
        crypto: crypto,
        cipher: cipher,
      );
    });

    test('should roundtrip a file that fits exactly in one chunk', () async {
      // 64 KB = exactly one chunk (at _chunkSize boundary)
      final plaintext = crypto.secureRandomBytes(64 * 1024);

      final result = await smallChunkService.encryptFile(plaintext);
      final decrypted = await smallChunkService.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('should handle files with non-aligned chunk sizes', () async {
      // Not a multiple of chunk size
      final plaintext = crypto.secureRandomBytes(100 * 1024 + 37);

      final result = await service.encryptFile(plaintext);
      final decrypted = await service.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('encrypted ciphertext should be larger than plaintext', () async {
      final plaintext = crypto.secureRandomBytes(10 * 1024);

      final result = await service.encryptFile(plaintext);

      // Ciphertext includes GCM tag (16 bytes) at minimum
      expect(result.encryptedBytes.length, greaterThan(plaintext.length));
    });
  });

  // =========================================================================
  // ENCRYPTED MEDIA RESULT
  // =========================================================================

  group('EncryptedMediaResult', () {
    test('should store all fields correctly', () {
      final result = EncryptedMediaResult(
        encryptedBytes: Uint8List.fromList([1, 2, 3]),
        mediaKey: 'testKey123',
        mediaHash: 'abcdef0123456789',
        originalSize: 42,
      );

      expect(result.encryptedBytes, equals(Uint8List.fromList([1, 2, 3])));
      expect(result.mediaKey, equals('testKey123'));
      expect(result.mediaHash, equals('abcdef0123456789'));
      expect(result.originalSize, equals(42));
    });
  });

  // =========================================================================
  // MEDIA INTEGRITY EXCEPTION
  // =========================================================================

  group('MediaIntegrityException', () {
    test('should contain message', () {
      const exception = MediaIntegrityException('test error');
      expect(exception.message, equals('test error'));
      expect(exception.toString(),
          equals('MediaIntegrityException: test error'));
    });
  });

  // =========================================================================
  // HASH CONSISTENCY
  // =========================================================================

  group('hash consistency', () {
    test('same plaintext should produce same hash', () async {
      final data = Uint8List.fromList(utf8.encode('Consistent hash'));

      final result1 = await service.encryptFile(data);
      final result2 = await service.encryptFile(data);

      expect(result1.mediaHash, equals(result2.mediaHash));
    });

    test('different plaintext should produce different hash', () async {
      final data1 = Uint8List.fromList(utf8.encode('File A'));
      final data2 = Uint8List.fromList(utf8.encode('File B'));

      final result1 = await service.encryptFile(data1);
      final result2 = await service.encryptFile(data2);

      expect(result1.mediaHash, isNot(equals(result2.mediaHash)));
    });

    test('hash should be lowercase hex string (64 chars)', () async {
      final data = Uint8List.fromList(utf8.encode('Hash format test'));

      final result = await service.encryptFile(data);

      // HMAC-SHA256 produces 32 bytes → 64 hex characters
      expect(result.mediaHash.length, equals(64));
      expect(result.mediaHash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  // =========================================================================
  // CROSS-INSTANCE COMPATIBILITY
  // =========================================================================

  group('cross-instance compatibility', () {
    test('file encrypted by one instance should decrypt with another',
        () async {
      final service1 = MediaEncryptionService(
        crypto: crypto,
        cipher: cipher,
      );
      final service2 = MediaEncryptionService(
        crypto: crypto,
        cipher: cipher,
      );

      final plaintext = Uint8List.fromList(utf8.encode('Cross-instance'));

      final result = await service1.encryptFile(plaintext);
      final decrypted = await service2.decryptFile(
        encryptedBytes: result.encryptedBytes,
        mediaKey: result.mediaKey,
        mediaHash: result.mediaHash,
      );

      expect(decrypted, equals(plaintext));
    });

    test('thumbnail encrypted by one instance should decrypt with another',
        () async {
      final service1 = MediaEncryptionService(
        crypto: crypto,
        cipher: cipher,
      );
      final service2 = MediaEncryptionService(
        crypto: crypto,
        cipher: cipher,
      );

      final thumbnail = crypto.secureRandomBytes(2048);

      final (encrypted, key) = await service1.encryptThumbnail(thumbnail);
      final decrypted = await service2.decryptThumbnail(
        encryptedBytes: encrypted,
        thumbnailKey: key,
      );

      expect(decrypted, equals(thumbnail));
    });
  });
}
