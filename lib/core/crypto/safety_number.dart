import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Safety number generation for identity key verification.
///
/// Generates a human-readable fingerprint from two users' identity keys
/// that can be compared in-person or via QR code to verify identity.
/// Based on the Signal Protocol safety number specification.
class SafetyNumber {
  static const _iterations = 5200;
  static const _fingerprintVersion = 0;

  /// Generate a safety number for a conversation between two users.
  ///
  /// The safety number is deterministic and order-independent:
  /// safetyNumber(A, B) == safetyNumber(B, A)
  ///
  /// Returns a 60-digit numeric string displayed in groups of 5.
  static Future<String> generate({
    required String localUserId,
    required Uint8List localIdentityKey,
    required String remoteUserId,
    required Uint8List remoteIdentityKey,
  }) async {
    // Generate fingerprint for each party
    final localFingerprint = await _computeFingerprint(
      localUserId,
      localIdentityKey,
    );
    final remoteFingerprint = await _computeFingerprint(
      remoteUserId,
      remoteIdentityKey,
    );

    // Sort to make order-independent
    final fingerprints = [localFingerprint, remoteFingerprint];
    fingerprints.sort((a, b) => a.compareTo(b));

    return '${fingerprints[0]}${fingerprints[1]}';
  }

  /// Compute a 30-digit fingerprint for one party.
  ///
  /// Uses iterated SHA-512 hashing as specified by Signal.
  static Future<String> _computeFingerprint(
    String userId,
    Uint8List identityKey,
  ) async {
    final sha512 = Sha512();
    final userIdBytes = utf8.encode(userId);

    // Version byte + identity key + user ID
    var input = Uint8List.fromList([
      _fingerprintVersion,
      ...identityKey,
      ...userIdBytes,
    ]);

    // Iterate SHA-512
    for (var i = 0; i < _iterations; i++) {
      final hash = await sha512.hash(
        Uint8List.fromList([...input, ...identityKey]),
      );
      input = Uint8List.fromList(hash.bytes);
    }

    // Encode hash bytes as 30-digit number (5 digits per 4 bytes, 6 groups)
    final digits = StringBuffer();
    for (var i = 0; i < 30; i += 5) {
      final byteIndex = (i ~/ 5) * 4;
      if (byteIndex + 4 <= input.length) {
        final value = (input[byteIndex] << 24) |
            (input[byteIndex + 1] << 16) |
            (input[byteIndex + 2] << 8) |
            input[byteIndex + 3];
        digits.write((value % 100000).toString().padLeft(5, '0'));
      }
    }

    return digits.toString();
  }

  /// Format a 60-digit safety number for display.
  ///
  /// Groups digits into blocks of 5 separated by spaces,
  /// with a line break every 20 digits.
  static String format(String safetyNumber) {
    final buffer = StringBuffer();
    for (var i = 0; i < safetyNumber.length; i += 5) {
      if (i > 0 && i % 20 == 0) {
        buffer.write('\n');
      } else if (i > 0) {
        buffer.write(' ');
      }
      final end = (i + 5).clamp(0, safetyNumber.length);
      buffer.write(safetyNumber.substring(i, end));
    }
    return buffer.toString();
  }
}
