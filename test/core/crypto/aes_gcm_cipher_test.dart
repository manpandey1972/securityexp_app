import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/aes_gcm_cipher.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';

void main() {
  late AesGcmCipher cipher;
  late NativeCryptoProvider crypto;

  setUp(() {
    crypto = NativeCryptoProvider();
    cipher = AesGcmCipher(crypto);
  });

  group('AesGcmCipher - Encrypt/Decrypt', () {
    test('should encrypt and decrypt round-trip', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(
        utf8.encode('Hello, encrypted world!'),
      );

      final ciphertext = await cipher.encrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      final decrypted = await cipher.decrypt(
        key: key,
        iv: iv,
        ciphertext: ciphertext,
      );

      expect(decrypted, equals(plaintext));
      expect(utf8.decode(decrypted), 'Hello, encrypted world!');
    });

    test('should encrypt and decrypt with AAD', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('With header'));
      final aad = Uint8List.fromList(utf8.encode('{"msg_num":42}'));

      final ciphertext = await cipher.encrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
        aad: aad,
      );

      final decrypted = await cipher.decrypt(
        key: key,
        iv: iv,
        ciphertext: ciphertext,
        aad: aad,
      );

      expect(decrypted, equals(plaintext));
    });
  });

  group('AesGcmCipher - Input Validation', () {
    test('should reject key shorter than 32 bytes', () async {
      final shortKey = Uint8List(16);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      expect(
        () => cipher.encrypt(key: shortKey, iv: iv, plaintext: plaintext),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject key longer than 32 bytes', () async {
      final longKey = Uint8List(48);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      expect(
        () => cipher.encrypt(key: longKey, iv: iv, plaintext: plaintext),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject IV shorter than 12 bytes', () async {
      final key = crypto.secureRandomBytes(32);
      final shortIv = Uint8List(8);
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      expect(
        () => cipher.encrypt(key: key, iv: shortIv, plaintext: plaintext),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject IV longer than 12 bytes', () async {
      final key = crypto.secureRandomBytes(32);
      final longIv = Uint8List(16);
      final plaintext = Uint8List.fromList(utf8.encode('test'));

      expect(
        () => cipher.encrypt(key: key, iv: longIv, plaintext: plaintext),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject ciphertext shorter than 16 bytes on decrypt', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final shortCiphertext = Uint8List(10);

      expect(
        () => cipher.decrypt(
          key: key,
          iv: iv,
          ciphertext: shortCiphertext,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('AesGcmCipher - Authentication', () {
    test('should fail decryption with tampered ciphertext', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('Authenticated'));

      final ciphertext = await cipher.encrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      // Tamper with ciphertext
      ciphertext[0] ^= 0xFF;

      expect(
        () => cipher.decrypt(key: key, iv: iv, ciphertext: ciphertext),
        throwsA(anything),
      );
    });

    test('should fail decryption with tampered GCM tag', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('Tag test'));

      final ciphertext = await cipher.encrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
      );

      // Tamper with the last byte (part of GCM tag)
      ciphertext[ciphertext.length - 1] ^= 0xFF;

      expect(
        () => cipher.decrypt(key: key, iv: iv, ciphertext: ciphertext),
        throwsA(anything),
      );
    });

    test('should fail decryption with mismatched AAD', () async {
      final key = crypto.secureRandomBytes(32);
      final iv = crypto.secureRandomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode('AAD mismatch'));
      final aad = Uint8List.fromList(utf8.encode('original'));

      final ciphertext = await cipher.encrypt(
        key: key,
        iv: iv,
        plaintext: plaintext,
        aad: aad,
      );

      final wrongAad = Uint8List.fromList(utf8.encode('modified'));

      expect(
        () => cipher.decrypt(
          key: key,
          iv: iv,
          ciphertext: ciphertext,
          aad: wrongAad,
        ),
        throwsA(anything),
      );
    });
  });
}
