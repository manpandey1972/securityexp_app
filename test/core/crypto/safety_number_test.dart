import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/safety_number.dart';

void main() {
  group('SafetyNumber', () {
    // Stable test keys for determinism
    final aliceKey = Uint8List.fromList(List.generate(32, (i) => i));
    final bobKey = Uint8List.fromList(List.generate(32, (i) => i + 32));

    test('should generate 60-digit safety number', () async {
      final safetyNumber = await SafetyNumber.generate(
        localUserId: 'alice_123',
        localIdentityKey: aliceKey,
        remoteUserId: 'bob_456',
        remoteIdentityKey: bobKey,
      );

      // Should be exactly 60 digits
      expect(safetyNumber.length, 60);
      expect(RegExp(r'^\d{60}$').hasMatch(safetyNumber), true);
    });

    test('should be order-independent', () async {
      final aliceSees = await SafetyNumber.generate(
        localUserId: 'alice_123',
        localIdentityKey: aliceKey,
        remoteUserId: 'bob_456',
        remoteIdentityKey: bobKey,
      );

      final bobSees = await SafetyNumber.generate(
        localUserId: 'bob_456',
        localIdentityKey: bobKey,
        remoteUserId: 'alice_123',
        remoteIdentityKey: aliceKey,
      );

      expect(aliceSees, equals(bobSees));
    });

    test('should be deterministic', () async {
      final sn1 = await SafetyNumber.generate(
        localUserId: 'user_a',
        localIdentityKey: aliceKey,
        remoteUserId: 'user_b',
        remoteIdentityKey: bobKey,
      );

      final sn2 = await SafetyNumber.generate(
        localUserId: 'user_a',
        localIdentityKey: aliceKey,
        remoteUserId: 'user_b',
        remoteIdentityKey: bobKey,
      );

      expect(sn1, equals(sn2));
    });

    test('should change when identity key changes', () async {
      final originalSn = await SafetyNumber.generate(
        localUserId: 'alice',
        localIdentityKey: aliceKey,
        remoteUserId: 'bob',
        remoteIdentityKey: bobKey,
      );

      // Change one bit of Bob's key
      final modifiedBobKey = Uint8List.fromList(bobKey);
      modifiedBobKey[0] ^= 0x01;

      final changedSn = await SafetyNumber.generate(
        localUserId: 'alice',
        localIdentityKey: aliceKey,
        remoteUserId: 'bob',
        remoteIdentityKey: modifiedBobKey,
      );

      expect(changedSn, isNot(equals(originalSn)));
    });

    test('should change for different user IDs', () async {
      final sn1 = await SafetyNumber.generate(
        localUserId: 'alice',
        localIdentityKey: aliceKey,
        remoteUserId: 'bob',
        remoteIdentityKey: bobKey,
      );

      final sn2 = await SafetyNumber.generate(
        localUserId: 'alice',
        localIdentityKey: aliceKey,
        remoteUserId: 'charlie',
        remoteIdentityKey: bobKey,
      );

      expect(sn1, isNot(equals(sn2)));
    });
  });

  group('SafetyNumber.format', () {
    test('should format into groups of 5 with spaces', () {
      final formatted = SafetyNumber.format(
        '123456789012345678901234567890123456789012345678901234567890',
      );

      // Groups of 5 digits, separated by spaces, every 20 digits a newline
      expect(formatted.contains(' '), true);
      expect(formatted.contains('\n'), true);

      // Verify all digits are preserved
      final digitsOnly = formatted.replaceAll(RegExp(r'[\s\n]'), '');
      expect(digitsOnly.length, 60);
    });
  });
}
