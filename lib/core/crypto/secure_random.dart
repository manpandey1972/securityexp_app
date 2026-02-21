import 'dart:math';
import 'dart:typed_data';

/// Platform-agnostic cryptographically secure random number generator.
///
/// Wraps `dart:math` `Random.secure()` which delegates to the platform
/// CSPRNG (SecRandomCopyBytes on iOS, /dev/urandom on Android/Linux).
class SecureRandom {
  static final _random = Random.secure();

  /// Generate [length] cryptographically secure random bytes.
  static Uint8List generateBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Generate a random 96-bit (12-byte) IV for AES-GCM.
  static Uint8List generateIv() => generateBytes(12);

  /// Generate a random 256-bit (32-byte) AES key.
  static Uint8List generateAesKey() => generateBytes(32);

  /// Generate a random uint32 registration ID.
  static int generateRegistrationId() {
    return _random.nextInt(0x7FFFFFFF); // Max positive 32-bit int
  }

  /// Generate a random pre-key ID.
  static int generatePreKeyId() {
    return _random.nextInt(0xFFFFFF); // 24-bit range
  }
}
