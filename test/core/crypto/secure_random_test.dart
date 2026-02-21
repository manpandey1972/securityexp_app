import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart';

void main() {
  group('SecureRandom', () {
    test('generateBytes should produce requested length', () {
      final bytes = SecureRandom.generateBytes(32);
      expect(bytes.length, 32);
    });

    test('generateBytes should produce unique output', () {
      final a = SecureRandom.generateBytes(32);
      final b = SecureRandom.generateBytes(32);
      expect(a, isNot(equals(b)));
    });

    test('generateIv should produce 12-byte nonce', () {
      final iv = SecureRandom.generateIv();
      expect(iv.length, 12);
    });

    test('generateAesKey should produce 32-byte key', () {
      final key = SecureRandom.generateAesKey();
      expect(key.length, 32);
    });

    test('generateRegistrationId should be positive', () {
      final id = SecureRandom.generateRegistrationId();
      expect(id, greaterThan(0));
    });

    test('generateRegistrationId should be within uint32 range', () {
      // Run multiple times to get statistical confidence
      for (var i = 0; i < 100; i++) {
        final id = SecureRandom.generateRegistrationId();
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThan(0x7FFFFFFF));
      }
    });

    test('generatePreKeyId should be positive', () {
      final id = SecureRandom.generatePreKeyId();
      expect(id, greaterThan(0));
    });

    test('generateBytes should handle edge cases', () {
      expect(SecureRandom.generateBytes(0).length, 0);
      expect(SecureRandom.generateBytes(1).length, 1);
      expect(SecureRandom.generateBytes(256).length, 256);
    });
  });
}
