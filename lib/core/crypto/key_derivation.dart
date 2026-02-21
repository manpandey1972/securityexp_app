import 'dart:convert';
import 'dart:typed_data';

import 'package:securityexperts_app/core/crypto/crypto_provider.dart';

/// HKDF-SHA-256 and HMAC-SHA-256 key derivation utilities.
///
/// Implements the key derivation functions used by the Signal Protocol:
/// - HKDF for deriving root keys and chain keys from DH shared secrets
/// - HMAC-SHA-256 for symmetric chain key ratcheting
class KeyDerivation {
  final CryptoProvider _crypto;

  /// Info string prefix for HKDF used by the Signal Protocol.
  static final _protocolInfo = utf8.encode('SecurityExpertsE2EE');

  const KeyDerivation(this._crypto);

  // =========================================================================
  // X3DH Key Derivation
  // =========================================================================

  /// Derive the initial root key and chain keys from the X3DH shared secret.
  ///
  /// Follows Signal Protocol spec: HKDF(input=DH outputs, salt=0, info="SecurityExpertsE2EE")
  /// Returns (rootKey, sendingChainKey, receivingChainKey) each 32 bytes.
  Future<({Uint8List rootKey, Uint8List chainKey})> deriveX3dhKeys(
    Uint8List sharedSecret,
  ) async {
    // Salt for initial key derivation (all zeros per Signal spec)
    final salt = Uint8List(32);

    // Derive 64 bytes: first 32 = root key, next 32 = chain key
    final derived = await _crypto.hkdfDerive(
      inputKeyMaterial: sharedSecret,
      salt: salt,
      info: Uint8List.fromList([..._protocolInfo, ...utf8.encode('_x3dh')]),
      outputLength: 64,
    );

    return (
      rootKey: Uint8List.fromList(derived.sublist(0, 32)),
      chainKey: Uint8List.fromList(derived.sublist(32, 64)),
    );
  }

  // =========================================================================
  // Double Ratchet Key Derivation
  // =========================================================================

  /// Perform a DH ratchet step: derive new root key and chain key
  /// from the current root key and a new DH shared secret.
  ///
  /// HKDF(input=dhOutput, salt=rootKey, info="SecurityExpertsE2EE_ratchet")
  /// Returns (newRootKey, newChainKey) each 32 bytes.
  Future<({Uint8List rootKey, Uint8List chainKey})> deriveRatchetKeys(
    Uint8List rootKey,
    Uint8List dhOutput,
  ) async {
    final derived = await _crypto.hkdfDerive(
      inputKeyMaterial: dhOutput,
      salt: rootKey,
      info: Uint8List.fromList(
        [..._protocolInfo, ...utf8.encode('_ratchet')],
      ),
      outputLength: 64,
    );

    return (
      rootKey: Uint8List.fromList(derived.sublist(0, 32)),
      chainKey: Uint8List.fromList(derived.sublist(32, 64)),
    );
  }

  /// Advance a chain key to derive the next chain key and a message key.
  ///
  /// Uses HMAC-SHA-256 as specified by the Signal Protocol:
  /// - messageKey = HMAC(chainKey, 0x01)
  /// - nextChainKey = HMAC(chainKey, 0x02)
  Future<({Uint8List messageKey, Uint8List nextChainKey})> advanceChainKey(
    Uint8List chainKey,
  ) async {
    final messageKey = await _crypto.hmacSha256(
      chainKey,
      Uint8List.fromList([0x01]),
    );

    final nextChainKey = await _crypto.hmacSha256(
      chainKey,
      Uint8List.fromList([0x02]),
    );

    return (
      messageKey: messageKey,
      nextChainKey: nextChainKey,
    );
  }

  /// Derive AES-256-GCM encryption key and IV from a message key.
  ///
  /// HKDF(input=messageKey, salt=0, info="SecurityExpertsE2EE_msg")
  /// Returns 44 bytes: 32-byte AES key + 12-byte IV.
  Future<({Uint8List aesKey, Uint8List iv})> deriveMessageEncryptionKeys(
    Uint8List messageKey,
  ) async {
    final derived = await _crypto.hkdfDerive(
      inputKeyMaterial: messageKey,
      salt: Uint8List(32), // zero salt
      info: Uint8List.fromList([..._protocolInfo, ...utf8.encode('_msg')]),
      outputLength: 44,
    );

    return (
      aesKey: Uint8List.fromList(derived.sublist(0, 32)),
      iv: Uint8List.fromList(derived.sublist(32, 44)),
    );
  }

  // =========================================================================
  // Utility
  // =========================================================================

  /// Concatenate multiple byte arrays into one (for X3DH secret combination).
  static Uint8List concatenate(List<Uint8List> inputs) {
    final totalLength = inputs.fold<int>(0, (sum, e) => sum + e.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final input in inputs) {
      result.setRange(offset, offset + input.length, input);
      offset += input.length;
    }
    return result;
  }
}
