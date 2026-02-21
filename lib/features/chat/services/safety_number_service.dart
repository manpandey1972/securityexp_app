import 'package:securityexperts_app/core/crypto/safety_number.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/prekey_repository.dart';

/// Service for generating and verifying safety numbers between users.
///
/// Safety numbers are 60-digit fingerprints derived from both users'
/// identity keys. They can be compared in-person or via QR code to
/// verify that no MITM attack has occurred on the key exchange.
///
/// Usage:
/// ```dart
/// final service = sl<SafetyNumberService>();
/// final result = await service.generateSafetyNumber(
///   localUserId: 'alice',
///   remoteUserId: 'bob',
/// );
/// // Display result.formatted to user for verification
/// ```
class SafetyNumberService {
  final IKeyStoreRepository _keyStore;
  final PreKeyRepository _preKeyRepo;
  final AppLogger _log;

  static const _tag = 'SafetyNumberService';

  /// In-memory cache of verified user IDs.
  /// Users explicitly verified via safety number comparison.
  final Set<String> _verifiedUsers = {};

  SafetyNumberService({
    required IKeyStoreRepository keyStore,
    required PreKeyRepository preKeyRepo,
    required AppLogger log,
  })  : _keyStore = keyStore,
        _preKeyRepo = preKeyRepo,
        _log = log;

  // =========================================================================
  // Safety Number Generation
  // =========================================================================

  /// Generate a safety number for a conversation with [remoteUserId].
  ///
  /// Returns null if either user's identity key is not available.
  Future<SafetyNumberResult?> generateSafetyNumber({
    required String localUserId,
    required String remoteUserId,
  }) async {
    try {
      // Get local identity key
      final localIdentity = await _keyStore.getIdentityKeyPair();
      if (localIdentity == null) {
        _log.warning('No local identity key for safety number', tag: _tag);
        return null;
      }

      // Get remote identity key (from local TOFU store first)
      var remoteIdentityKey = await _keyStore.getRemoteIdentityKey(remoteUserId);

      if (remoteIdentityKey == null) {
        // Try fetching from Firestore
        final bundle = await _preKeyRepo.fetchPreKeyBundle(
          userId: remoteUserId,
        );
        if (bundle == null) {
          _log.warning(
            'No remote identity key for $remoteUserId',
            tag: _tag,
          );
          return null;
        }
        remoteIdentityKey = bundle.identityKey;
      }

      // Generate the 60-digit safety number
      final safetyNumber = await SafetyNumber.generate(
        localUserId: localUserId,
        localIdentityKey: localIdentity.publicKey,
        remoteUserId: remoteUserId,
        remoteIdentityKey: remoteIdentityKey,
      );

      return SafetyNumberResult(
        safetyNumber: safetyNumber,
        formatted: SafetyNumber.format(safetyNumber),
        isVerified: _verifiedUsers.contains(remoteUserId),
        localUserId: localUserId,
        remoteUserId: remoteUserId,
      );
    } catch (e) {
      _log.error('Failed to generate safety number: $e', tag: _tag);
      return null;
    }
  }

  // =========================================================================
  // Verification State
  // =========================================================================

  /// Mark a user as verified after successful safety number comparison.
  ///
  /// This persists in-memory for the session. For permanent verification,
  /// the `IdentityKeyStatus.verified` state is stored in the key store.
  void markVerified(String remoteUserId) {
    _verifiedUsers.add(remoteUserId);
    _log.info('User $remoteUserId marked as verified', tag: _tag);
  }

  /// Remove verification status for a user (e.g., after key change).
  void markUnverified(String remoteUserId) {
    _verifiedUsers.remove(remoteUserId);
    _log.info('User $remoteUserId verification removed', tag: _tag);
  }

  /// Check if a user has been verified via safety number comparison.
  bool isVerified(String remoteUserId) {
    return _verifiedUsers.contains(remoteUserId);
  }

  /// Compare two safety numbers for equality.
  ///
  /// Used when one user scans the other's QR code.
  bool compareSafetyNumbers(String local, String scanned) {
    return local == scanned;
  }

  /// Clear all verification state (sign-out).
  void clearAll() {
    _verifiedUsers.clear();
  }
}

/// Result of a safety number generation.
class SafetyNumberResult {
  /// The raw 60-digit safety number.
  final String safetyNumber;

  /// Formatted for display (groups of 5 digits with line breaks).
  final String formatted;

  /// Whether the remote user has been verified.
  final bool isVerified;

  /// The local user ID.
  final String localUserId;

  /// The remote user ID.
  final String remoteUserId;

  const SafetyNumberResult({
    required this.safetyNumber,
    required this.formatted,
    required this.isVerified,
    required this.localUserId,
    required this.remoteUserId,
  });
}
