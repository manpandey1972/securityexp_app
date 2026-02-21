import 'dart:convert';
import 'dart:typed_data';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_backup_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';

/// High-level service for E2EE key backup and recovery.
///
/// Wraps [KeyBackupRepository] with:
/// - Key export (serializes all local key material)
/// - Key import (deserializes and restores key material)
/// - Backup status tracking
/// - Passphrase validation
///
/// Used by the UI layer to provide backup/restore functionality.
class KeyBackupService {
  final KeyBackupRepository _backupRepo;
  final IKeyStoreRepository _keyStore;
  final AppLogger _log;

  static const _tag = 'KeyBackupService';

  /// Minimum passphrase length for backup encryption.
  static const minPassphraseLength = 8;

  KeyBackupService({
    required KeyBackupRepository backupRepo,
    required IKeyStoreRepository keyStore,
    required AppLogger log,
  })  : _backupRepo = backupRepo,
        _keyStore = keyStore,
        _log = log;

  // =========================================================================
  // Backup Operations
  // =========================================================================

  /// Create an encrypted backup of all local E2EE key material.
  ///
  /// [passphrase] must be at least [minPassphraseLength] characters.
  ///
  /// Exports:
  /// - Identity key pair (X25519 DH + Ed25519 signing)
  /// - Registration ID
  ///
  /// Returns true if backup was created successfully.
  Future<bool> createBackup({required String passphrase}) async {
    if (!_isValidPassphrase(passphrase)) {
      _log.warning('Invalid passphrase for backup', tag: _tag);
      return false;
    }

    try {
      _log.info('Creating E2EE key backup', tag: _tag);

      final keyData = await _exportKeyData();
      if (keyData == null) {
        _log.warning('No key data to back up', tag: _tag);
        return false;
      }

      await _backupRepo.createBackup(
        passphrase: passphrase,
        keyData: keyData,
      );

      _log.info('E2EE key backup created successfully', tag: _tag);
      return true;
    } catch (e) {
      _log.error('Failed to create E2EE key backup: $e', tag: _tag);
      return false;
    }
  }

  /// Restore E2EE keys from an encrypted backup.
  ///
  /// [passphrase] must match the passphrase used during backup creation.
  ///
  /// Returns true if keys were restored successfully.
  /// Returns false if the passphrase is wrong or no backup exists.
  Future<bool> restoreBackup({required String passphrase}) async {
    try {
      _log.info('Restoring E2EE key backup', tag: _tag);

      final keyData = await _backupRepo.restoreBackup(passphrase: passphrase);
      if (keyData == null) {
        _log.warning(
          'Backup restore failed — wrong passphrase or no backup',
          tag: _tag,
        );
        return false;
      }

      await _importKeyData(keyData);

      _log.info('E2EE key backup restored successfully', tag: _tag);
      return true;
    } catch (e) {
      _log.error('Failed to restore E2EE key backup: $e', tag: _tag);
      return false;
    }
  }

  /// Delete the cloud key backup.
  Future<bool> deleteBackup() async {
    try {
      await _backupRepo.deleteBackup();
      _log.info('E2EE key backup deleted', tag: _tag);
      return true;
    } catch (e) {
      _log.error('Failed to delete backup: $e', tag: _tag);
      return false;
    }
  }

  /// Check if a key backup exists in the cloud.
  Future<bool> hasBackup() async {
    try {
      return await _backupRepo.hasBackup();
    } catch (e) {
      _log.error('Failed to check backup status: $e', tag: _tag);
      return false;
    }
  }

  // =========================================================================
  // Passphrase Validation
  // =========================================================================

  /// Validate passphrase meets minimum requirements.
  bool _isValidPassphrase(String passphrase) {
    return passphrase.length >= minPassphraseLength;
  }

  /// Check passphrase strength.
  ///
  /// Returns a score from 0 (weak) to 3 (strong).
  PassphraseStrength evaluatePassphraseStrength(String passphrase) {
    if (passphrase.length < minPassphraseLength) {
      return PassphraseStrength.tooShort;
    }

    var score = 0;

    // Length bonus
    if (passphrase.length >= 12) score++;
    if (passphrase.length >= 16) score++;

    // Character variety
    if (RegExp(r'[a-z]').hasMatch(passphrase)) score++;
    if (RegExp(r'[A-Z]').hasMatch(passphrase)) score++;
    if (RegExp(r'[0-9]').hasMatch(passphrase)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(passphrase)) score++;

    if (score <= 2) return PassphraseStrength.weak;
    if (score <= 4) return PassphraseStrength.moderate;
    return PassphraseStrength.strong;
  }

  // =========================================================================
  // Key Serialization
  // =========================================================================

  /// Export all local key material for backup.
  Future<Map<String, dynamic>?> _exportKeyData() async {
    final identity = await _keyStore.getIdentityKeyPair();
    if (identity == null) return null;

    return {
      'version': 1,
      'identity': {
        'publicKey': base64Encode(identity.publicKey),
        'privateKey': base64Encode(identity.privateKey),
        'signingPublicKey': base64Encode(identity.signingPublicKey),
        'signingPrivateKey': base64Encode(identity.signingPrivateKey),
        'registrationId': identity.registrationId,
      },
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Import key material from a backup.
  Future<void> _importKeyData(Map<String, dynamic> keyData) async {
    final version = keyData['version'] as int?;
    if (version != 1) {
      throw FormatException('Unsupported backup version: $version');
    }

    final identityData = keyData['identity'] as Map<String, dynamic>;

    // Decode backed-up key material
    final restoredKeyPair = IdentityKeyPair(
      publicKey: Uint8List.fromList(
        base64Decode(identityData['publicKey'] as String),
      ),
      privateKey: Uint8List.fromList(
        base64Decode(identityData['privateKey'] as String),
      ),
      signingPublicKey: Uint8List.fromList(
        base64Decode(identityData['signingPublicKey'] as String),
      ),
      signingPrivateKey: Uint8List.fromList(
        base64Decode(identityData['signingPrivateKey'] as String),
      ),
      registrationId: identityData['registrationId'] as int,
    );

    // Clear existing keys before importing
    await _keyStore.clearAll();

    // Store the restored identity key pair
    await _keyStore.storeIdentityKeyPair(restoredKeyPair);

    _log.info(
      'Key data imported (version $version, '
      'registrationId: ${restoredKeyPair.registrationId})',
      tag: _tag,
    );
  }
}

/// Passphrase strength levels.
enum PassphraseStrength {
  /// Passphrase is too short (below minimum length).
  tooShort,

  /// Passphrase meets minimum requirements but is weak.
  weak,

  /// Passphrase has moderate strength.
  moderate,

  /// Passphrase is strong.
  strong,
}
