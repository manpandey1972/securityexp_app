import 'dart:typed_data';

import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

/// Abstract interface for cryptographic key storage.
///
/// Implementations must provide secure, encrypted storage for
/// sensitive key material. Keys must be protected at rest using
/// platform-native mechanisms.
///
/// Implementations:
/// - [NativeKeyStoreRepository]: iOS Keychain / Android Keystore
/// - WebKeyStoreRepository: IndexedDB + CryptoKey wrapping (web)
abstract class IKeyStoreRepository {
  // =========================================================================
  // Identity Key Pair
  // =========================================================================

  /// Generate and persist a new identity key pair.
  /// Called once per device during E2EE registration.
  Future<IdentityKeyPair> generateAndStoreIdentityKeyPair();

  /// Store an existing identity key pair (e.g. from backup restore).
  ///
  /// Unlike [generateAndStoreIdentityKeyPair], this accepts an already-created
  /// key pair and persists it to the secure store. Used during key backup
  /// restore to import previously exported key material.
  Future<void> storeIdentityKeyPair(IdentityKeyPair keyPair);

  /// Retrieve the stored identity key pair for this device.
  /// Returns null if no identity key has been generated yet.
  Future<IdentityKeyPair?> getIdentityKeyPair();

  /// Delete the identity key pair (device deregistration).
  Future<void> deleteIdentityKeyPair();

  // =========================================================================
  // Signed Pre-Key
  // =========================================================================

  /// Store a signed pre-key (including private key).
  Future<void> storeSignedPreKey(SignedPreKey signedPreKey);

  /// Retrieve the current signed pre-key.
  Future<SignedPreKey?> getSignedPreKey(int keyId);

  /// Delete a signed pre-key.
  Future<void> deleteSignedPreKey(int keyId);

  // =========================================================================
  // One-Time Pre-Keys
  // =========================================================================

  /// Store a batch of one-time pre-keys (including private keys).
  Future<void> storeOneTimePreKeys(List<OneTimePreKey> preKeys);

  /// Retrieve a one-time pre-key by ID.
  Future<OneTimePreKey?> getOneTimePreKey(int keyId);

  /// Delete a consumed one-time pre-key.
  Future<void> deleteOneTimePreKey(int keyId);

  /// Get all stored one-time pre-key IDs.
  Future<List<int>> getOneTimePreKeyIds();

  // =========================================================================
  // Remote Identity Keys (TOFU)
  // =========================================================================

  /// Store a remote user's identity key (Trust On First Use).
  Future<void> storeRemoteIdentityKey(String userId, Uint8List identityKey);

  /// Retrieve stored identity key for a remote user.
  Future<Uint8List?> getRemoteIdentityKey(String userId);

  /// Check if a remote user's identity key has changed.
  Future<bool> hasIdentityKeyChanged(String userId, Uint8List currentKey);

  // =========================================================================
  // Lifecycle
  // =========================================================================

  /// Delete all stored key material (sign-out / account deletion).
  Future<void> clearAll();
}
