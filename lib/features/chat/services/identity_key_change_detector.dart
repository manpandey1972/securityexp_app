import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/prekey_repository.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';
import 'package:securityexperts_app/features/chat/services/safety_number_service.dart';

/// Detects when a contact's identity key has changed.
///
/// When a contact reinstalls the app, gets a new device, or (worst case)
/// is being impersonated via MITM, their identity key changes. This
/// detector compares the stored identity key against the current one
/// published in Firestore and flags mismatches.
///
/// Usage:
/// ```dart
/// final detector = sl<IdentityKeyChangeDetector>();
/// final status = await detector.checkIdentityKey('contact_id');
/// if (status == IdentityKeyStatus.changed) {
///   // Show warning banner in chat UI
/// }
/// ```
class IdentityKeyChangeDetector {
  final IKeyStoreRepository _keyStore;
  final PreKeyRepository _preKeyRepo;
  final SafetyNumberService _safetyNumberService;
  final AppLogger _log;

  static const _tag = 'IdentityKeyChangeDetector';

  /// Callback invoked when a contact's identity key changes.
  /// UI layers can register to show warning banners.
  void Function(String userId, IdentityKeyStatus status)? onKeyStatusChanged;

  IdentityKeyChangeDetector({
    required IKeyStoreRepository keyStore,
    required PreKeyRepository preKeyRepo,
    required SafetyNumberService safetyNumberService,
    required AppLogger log,
  })  : _keyStore = keyStore,
        _preKeyRepo = preKeyRepo,
        _safetyNumberService = safetyNumberService,
        _log = log;

  // =========================================================================
  // Identity Key Verification
  // =========================================================================

  /// Check the identity key status for a remote user.
  ///
  /// Returns:
  /// - [IdentityKeyStatus.unknown] — no stored key (first contact)
  /// - [IdentityKeyStatus.trusted] — stored key matches (TOFU verified)
  /// - [IdentityKeyStatus.changed] — key mismatch (device change or MITM)
  /// - [IdentityKeyStatus.verified] — manually verified via safety number
  Future<IdentityKeyStatus> checkIdentityKey(String remoteUserId) async {
    try {
      // Check if user was manually verified
      if (_safetyNumberService.isVerified(remoteUserId)) {
        // Even if verified, check if key has changed since verification
        final changed = await _hasKeyChangedSinceVerification(remoteUserId);
        if (changed) {
          // Key changed after verification — revoke verified status
          _safetyNumberService.markUnverified(remoteUserId);
          _notifyKeyStatusChanged(remoteUserId, IdentityKeyStatus.changed);
          return IdentityKeyStatus.changed;
        }
        return IdentityKeyStatus.verified;
      }

      // Get stored identity key (TOFU)
      final storedKey = await _keyStore.getRemoteIdentityKey(remoteUserId);
      if (storedKey == null) {
        return IdentityKeyStatus.unknown;
      }

      // Fetch current key from Firestore
      final bundle = await _preKeyRepo.fetchPreKeyBundle(
        userId: remoteUserId,
      );
      if (bundle == null) {
        return IdentityKeyStatus.unknown;
      }

      // Compare
      final changed = await _keyStore.hasIdentityKeyChanged(
        remoteUserId,
        bundle.identityKey,
      );

      if (changed) {
        _log.warning(
          'Identity key changed for user $remoteUserId',
          tag: _tag,
        );
        _notifyKeyStatusChanged(remoteUserId, IdentityKeyStatus.changed);
        return IdentityKeyStatus.changed;
      }

      return IdentityKeyStatus.trusted;
    } catch (e) {
      _log.error(
        'Failed to check identity key for $remoteUserId: $e',
        tag: _tag,
      );
      return IdentityKeyStatus.unknown;
    }
  }

  /// Accept a changed identity key and update the stored key.
  ///
  /// Call this when the user acknowledges the key change warning
  /// and chooses to continue communicating.
  Future<void> acceptKeyChange(String remoteUserId) async {
    try {
      final bundle = await _preKeyRepo.fetchPreKeyBundle(
        userId: remoteUserId,
      );
      if (bundle == null) {
        _log.warning('No bundle found for key change acceptance', tag: _tag);
        return;
      }

      await _keyStore.storeRemoteIdentityKey(
        remoteUserId,
        bundle.identityKey,
      );

      _log.info(
        'Accepted identity key change for $remoteUserId',
        tag: _tag,
      );

      _notifyKeyStatusChanged(remoteUserId, IdentityKeyStatus.trusted);
    } catch (e) {
      _log.error('Failed to accept key change: $e', tag: _tag);
    }
  }

  /// Check multiple contacts' identity keys at once.
  ///
  /// Useful for batch checking all contacts on app startup.
  Future<Map<String, IdentityKeyStatus>> checkMultiple(
    List<String> userIds,
  ) async {
    final results = <String, IdentityKeyStatus>{};
    for (final userId in userIds) {
      results[userId] = await checkIdentityKey(userId);
    }
    return results;
  }

  // =========================================================================
  // Private Helpers
  // =========================================================================

  /// Check if a key has changed since the user was verified.
  Future<bool> _hasKeyChangedSinceVerification(String remoteUserId) async {
    final storedKey = await _keyStore.getRemoteIdentityKey(remoteUserId);
    if (storedKey == null) return true;

    final bundle = await _preKeyRepo.fetchPreKeyBundle(
      userId: remoteUserId,
    );
    if (bundle == null) return false;

    return await _keyStore.hasIdentityKeyChanged(
      remoteUserId,
      bundle.identityKey,
    );
  }

  /// Notify listeners of a key status change.
  void _notifyKeyStatusChanged(
    String userId,
    IdentityKeyStatus status,
  ) {
    onKeyStatusChanged?.call(userId, status);
  }
}
