import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/key_derivation.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';

void main() {
  late KeyDerivation kdf;
  late NativeCryptoProvider crypto;

  setUp(() {
    crypto = NativeCryptoProvider();
    kdf = KeyDerivation(crypto);
  });

  // ===========================================================================
  // X3DH Key Derivation
  // ===========================================================================

  group('deriveX3dhKeys', () {
    test('should produce 32-byte root key and chain key', () async {
      final sharedSecret = crypto.secureRandomBytes(96);

      final (:rootKey, :chainKey) = await kdf.deriveX3dhKeys(sharedSecret);

      expect(rootKey.length, 32);
      expect(chainKey.length, 32);
    });

    test('should produce deterministic output', () async {
      final sharedSecret = Uint8List.fromList(
        List.generate(96, (i) => i % 256),
      );

      final result1 = await kdf.deriveX3dhKeys(sharedSecret);
      final result2 = await kdf.deriveX3dhKeys(sharedSecret);

      expect(result1.rootKey, equals(result2.rootKey));
      expect(result1.chainKey, equals(result2.chainKey));
    });

    test('should produce different keys for different inputs', () async {
      final secret1 = crypto.secureRandomBytes(96);
      final secret2 = crypto.secureRandomBytes(96);

      final result1 = await kdf.deriveX3dhKeys(secret1);
      final result2 = await kdf.deriveX3dhKeys(secret2);

      expect(result1.rootKey, isNot(equals(result2.rootKey)));
      expect(result1.chainKey, isNot(equals(result2.chainKey)));
    });

    test('root key and chain key should be different', () async {
      final sharedSecret = crypto.secureRandomBytes(96);

      final (:rootKey, :chainKey) = await kdf.deriveX3dhKeys(sharedSecret);

      expect(rootKey, isNot(equals(chainKey)));
    });
  });

  // ===========================================================================
  // DH Ratchet Key Derivation
  // ===========================================================================

  group('deriveRatchetKeys', () {
    test('should produce 32-byte keys', () async {
      final rootKey = crypto.secureRandomBytes(32);
      final dhOutput = crypto.secureRandomBytes(32);

      final result = await kdf.deriveRatchetKeys(rootKey, dhOutput);

      expect(result.rootKey.length, 32);
      expect(result.chainKey.length, 32);
    });

    test('should produce deterministic output', () async {
      final rootKey = Uint8List.fromList(List.generate(32, (i) => i));
      final dhOutput = Uint8List.fromList(List.generate(32, (i) => i + 32));

      final r1 = await kdf.deriveRatchetKeys(rootKey, dhOutput);
      final r2 = await kdf.deriveRatchetKeys(rootKey, dhOutput);

      expect(r1.rootKey, equals(r2.rootKey));
      expect(r1.chainKey, equals(r2.chainKey));
    });

    test('should produce new root key different from input', () async {
      final rootKey = crypto.secureRandomBytes(32);
      final dhOutput = crypto.secureRandomBytes(32);

      final result = await kdf.deriveRatchetKeys(rootKey, dhOutput);

      expect(result.rootKey, isNot(equals(rootKey)));
    });
  });

  // ===========================================================================
  // Chain Key Advancement
  // ===========================================================================

  group('advanceChainKey', () {
    test('should produce 32-byte message key and chain key', () async {
      final chainKey = crypto.secureRandomBytes(32);

      final (:messageKey, :nextChainKey) =
          await kdf.advanceChainKey(chainKey);

      expect(messageKey.length, 32);
      expect(nextChainKey.length, 32);
    });

    test('should produce deterministic output', () async {
      final chainKey = Uint8List.fromList(List.generate(32, (i) => i));

      final r1 = await kdf.advanceChainKey(chainKey);
      final r2 = await kdf.advanceChainKey(chainKey);

      expect(r1.messageKey, equals(r2.messageKey));
      expect(r1.nextChainKey, equals(r2.nextChainKey));
    });

    test('message key and next chain key should be different', () async {
      final chainKey = crypto.secureRandomBytes(32);

      final (:messageKey, :nextChainKey) =
          await kdf.advanceChainKey(chainKey);

      expect(messageKey, isNot(equals(nextChainKey)));
    });

    test('next chain key should be different from input', () async {
      final chainKey = crypto.secureRandomBytes(32);

      final (:nextChainKey, messageKey: _) =
          await kdf.advanceChainKey(chainKey);

      expect(nextChainKey, isNot(equals(chainKey)));
    });

    test('chaining should produce unique keys at each step', () async {
      var chainKey = crypto.secureRandomBytes(32);
      final messageKeys = <Uint8List>[];

      for (var i = 0; i < 10; i++) {
        final (:messageKey, :nextChainKey) =
            await kdf.advanceChainKey(chainKey);
        messageKeys.add(messageKey);
        chainKey = nextChainKey;
      }

      // All message keys should be unique
      for (var i = 0; i < messageKeys.length; i++) {
        for (var j = i + 1; j < messageKeys.length; j++) {
          expect(messageKeys[i], isNot(equals(messageKeys[j])));
        }
      }
    });
  });

  // ===========================================================================
  // Message Encryption Key Derivation
  // ===========================================================================

  group('deriveMessageEncryptionKeys', () {
    test('should produce 32-byte AES key and 12-byte IV', () async {
      final messageKey = crypto.secureRandomBytes(32);

      final (:aesKey, :iv) =
          await kdf.deriveMessageEncryptionKeys(messageKey);

      expect(aesKey.length, 32);
      expect(iv.length, 12);
    });

    test('should produce deterministic output', () async {
      final messageKey = Uint8List.fromList(List.generate(32, (i) => i));

      final r1 = await kdf.deriveMessageEncryptionKeys(messageKey);
      final r2 = await kdf.deriveMessageEncryptionKeys(messageKey);

      expect(r1.aesKey, equals(r2.aesKey));
      expect(r1.iv, equals(r2.iv));
    });

    test('different message keys produce different encryption keys', () async {
      final mk1 = crypto.secureRandomBytes(32);
      final mk2 = crypto.secureRandomBytes(32);

      final r1 = await kdf.deriveMessageEncryptionKeys(mk1);
      final r2 = await kdf.deriveMessageEncryptionKeys(mk2);

      expect(r1.aesKey, isNot(equals(r2.aesKey)));
      expect(r1.iv, isNot(equals(r2.iv)));
    });
  });

  // ===========================================================================
  // Utility
  // ===========================================================================

  group('concatenate', () {
    test('should concatenate multiple byte arrays', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([4, 5]);
      final c = Uint8List.fromList([6, 7, 8, 9]);

      final result = KeyDerivation.concatenate([a, b, c]);

      expect(result, equals(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9])));
    });

    test('should handle empty arrays', () {
      final result = KeyDerivation.concatenate([Uint8List(0), Uint8List(0)]);
      expect(result.length, 0);
    });

    test('should handle single array', () {
      final input = Uint8List.fromList([1, 2, 3]);
      final result = KeyDerivation.concatenate([input]);
      expect(result, equals(input));
    });

    test('should handle empty list', () {
      final result = KeyDerivation.concatenate([]);
      expect(result.length, 0);
    });
  });
}
