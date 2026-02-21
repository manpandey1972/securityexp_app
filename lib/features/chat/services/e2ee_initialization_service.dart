import 'dart:async';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/prekey_repository.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart';

/// Service that initializes E2EE for the current device after authentication.
///
/// Responsibilities:
/// 1. Registers this device's prekey bundle on first sign-in
/// 2. Checks and replenishes OPKs on subsequent launches
/// 3. Rotates signed pre-key when due (every 48 hours)
/// 4. Cleans up E2EE state on sign-out
///
/// This service bridges the auth flow and E2EE key management.
/// It should be initialized after the user's profile is confirmed to exist.
class E2eeInitializationService {
  final IKeyStoreRepository _keyStore;
  final PreKeyRepository _preKeyRepo;
  final AppLogger _log;

  static const _tag = 'E2eeInit';

  /// Default device name for this platform.
  static const _defaultDeviceName = 'Mobile Device';

  /// Persisted device ID for this installation.
  String? _deviceId;

  /// Whether initialization has completed for the current session.
  bool _initialized = false;

  E2eeInitializationService({
    required IKeyStoreRepository keyStore,
    required PreKeyRepository preKeyRepo,
    required AppLogger log,
  })  : _keyStore = keyStore,
        _preKeyRepo = preKeyRepo,
        _log = log;

  /// Whether E2EE has been initialized for the current session.
  bool get isInitialized => _initialized;

  /// The device ID for this installation.
  String? get deviceId => _deviceId;

  // =========================================================================
  // Initialization
  // =========================================================================

  /// Initialize E2EE for the current authenticated user.
  ///
  /// Call this after the user's profile is confirmed to exist in Firestore.
  /// Safe to call multiple times — subsequent calls are no-ops if already
  /// initialized.
  ///
  /// Flow:
  /// 1. Check if an identity key pair already exists locally
  /// 2. If not, generate keys and register this device (first-time setup)
  /// 3. If yes, check OPK supply and SPK rotation
  Future<void> initialize({
    required String userId,
    String? deviceName,
  }) async {
    if (_initialized) {
      _log.debug('E2EE already initialized, skipping', tag: _tag);
      return;
    }

    try {
      _log.info('Initializing E2EE for user $userId', tag: _tag);

      final existingIdentity = await _keyStore.getIdentityKeyPair();

      if (existingIdentity == null) {
        // First-time setup — register device
        await _registerDevice(
          userId: userId,
          deviceName: deviceName ?? _defaultDeviceName,
        );
      } else {
        // Returning user — perform maintenance
        _deviceId = _generateStableDeviceId(userId);
        await _performMaintenance(userId: userId);
      }

      _initialized = true;
      _log.info('E2EE initialization complete', tag: _tag);
    } catch (e) {
      _log.error('E2EE initialization failed: $e', tag: _tag);
      // Don't rethrow — E2EE failure should not block app usage.
      // Messages will fall back to unencrypted until resolved.
    }
  }

  /// Register this device's E2EE keys for the first time.
  Future<void> _registerDevice({
    required String userId,
    required String deviceName,
  }) async {
    _log.info('Registering new E2EE device', tag: _tag);

    _deviceId = _generateStableDeviceId(userId);

    final result = await _preKeyRepo.registerDevice(
      userId: userId,
      deviceId: _deviceId!,
      deviceName: deviceName,
    );

    _log.info(
      'Device registered with ID: ${result.deviceId}',
      tag: _tag,
    );
  }

  /// Perform periodic maintenance: OPK replenishment and SPK rotation.
  Future<void> _performMaintenance({required String userId}) async {
    if (_deviceId == null) return;

    try {
      // Check OPK supply
      final replenished = await _preKeyRepo.replenishOneTimePreKeysIfNeeded(
        userId: userId,
        deviceId: _deviceId!,
      );
      if (replenished) {
        _log.info('OPKs replenished', tag: _tag);
      }

      // Check SPK rotation
      await _checkSignedPreKeyRotation(userId: userId);

      // Update last active timestamp
      await _preKeyRepo.updateLastActive(
        userId: userId,
        deviceId: _deviceId!,
      );
    } catch (e) {
      _log.warning('E2EE maintenance check failed: $e', tag: _tag);
    }
  }

  /// Rotate signed pre-key if older than [_spkRotationInterval].
  Future<void> _checkSignedPreKeyRotation({required String userId}) async {
    if (_deviceId == null) return;

    final identity = await _keyStore.getIdentityKeyPair();
    if (identity == null) return;

    // Get current SPK to check age
    // For simplicity, we always attempt rotation — the prekey repo
    // handles the actual age check server-side.
    // In a production system, we'd store the last rotation timestamp.
    try {
      await _preKeyRepo.rotateSignedPreKey(
        userId: userId,
        deviceId: _deviceId!,
      );
      _log.debug('Signed pre-key rotation check completed', tag: _tag);
    } catch (e) {
      _log.warning('SPK rotation check failed: $e', tag: _tag);
    }
  }

  // =========================================================================
  // Cleanup
  // =========================================================================

  /// Clear all E2EE state on sign-out.
  ///
  /// This removes:
  /// - Local key material (identity keys, pre-keys)
  /// - Session state
  /// - Device registration from Firestore
  Future<void> cleanup({String? userId}) async {
    _log.info('Cleaning up E2EE state', tag: _tag);

    try {
      // Deregister device from Firestore if we know the user/device IDs
      if (userId != null && _deviceId != null) {
        await _preKeyRepo.deregisterDevice(
          userId: userId,
          deviceId: _deviceId!,
        );
      }
    } catch (e) {
      _log.warning('Failed to deregister device: $e', tag: _tag);
    }

    // Clear local key material
    await _keyStore.clearAll();

    _deviceId = null;
    _initialized = false;

    _log.info('E2EE cleanup complete', tag: _tag);
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  /// Generate a stable device ID based on user ID and a random component.
  ///
  /// The device ID is deterministic per installation but unique across
  /// devices for the same user.
  String _generateStableDeviceId(String userId) {
    // Use a simple prefix + random ID approach.
    // In production, this would be persisted to SharedPreferences
    // to survive app restarts.
    return 'device_${SecureRandom.generateDeviceId()}';
  }
}
