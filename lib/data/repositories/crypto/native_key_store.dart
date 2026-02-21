import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';

/// Native (iOS/Android) implementation of [IKeyStoreRepository].
///
/// Uses [FlutterSecureStorage] which delegates to:
/// - **iOS**: Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// - **Android**: AndroidKeyStore (hardware-backed when available)
///
/// All key material is encrypted at rest by the platform-native keystore.
class NativeKeyStoreRepository implements IKeyStoreRepository {
  final CryptoProvider _crypto;
  final FlutterSecureStorage _secureStorage;

  static const _identityKeyTag = 'e2ee_identity_key';
  static const _signedPreKeyPrefix = 'e2ee_spk_';
  static const _oneTimePreKeyPrefix = 'e2ee_opk_';
  static const _opkIdsKey = 'e2ee_opk_ids';
  static const _remoteIdentityPrefix = 'e2ee_remote_ik_';

  NativeKeyStoreRepository({
    required CryptoProvider crypto,
    FlutterSecureStorage? secureStorage,
  })  : _crypto = crypto,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
            );

  // =========================================================================
  // Identity Key Pair
  // =========================================================================

  @override
  Future<IdentityKeyPair> generateAndStoreIdentityKeyPair() async {
    // Generate X25519 key pair for DH key agreement
    final dhKeyPair = await _crypto.generateX25519KeyPair();

    // Generate Ed25519 key pair for identity signing
    final signingKeyPair = await _crypto.generateEd25519KeyPair();

    // Generate registration ID
    final registrationId = SecureRandom.generateRegistrationId();

    final identityKeyPair = IdentityKeyPair(
      publicKey: dhKeyPair.publicKey,
      privateKey: dhKeyPair.privateKey,
      signingPublicKey: signingKeyPair.publicKey,
      signingPrivateKey: signingKeyPair.privateKey,
      registrationId: registrationId,
    );

    // Store serialized key pair
    final data = identityKeyPair.toSecureStorage();
    await _secureStorage.write(
      key: _identityKeyTag,
      value: jsonEncode(data),
    );

    return identityKeyPair;
  }

  @override
  Future<IdentityKeyPair?> getIdentityKeyPair() async {
    final encoded = await _secureStorage.read(key: _identityKeyTag);
    if (encoded == null) return null;

    final data = Map<String, String>.from(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    return IdentityKeyPair.fromSecureStorage(data);
  }

  @override
  Future<void> deleteIdentityKeyPair() async {
    await _secureStorage.delete(key: _identityKeyTag);
  }

  // =========================================================================
  // Signed Pre-Key
  // =========================================================================

  @override
  Future<void> storeSignedPreKey(SignedPreKey signedPreKey) async {
    final data = {
      ...signedPreKey.toJson(),
      if (signedPreKey.privateKey != null)
        'private_key': base64Encode(signedPreKey.privateKey!),
    };

    await _secureStorage.write(
      key: '$_signedPreKeyPrefix${signedPreKey.keyId}',
      value: jsonEncode(data),
    );
  }

  @override
  Future<SignedPreKey?> getSignedPreKey(int keyId) async {
    final encoded = await _secureStorage.read(
      key: '$_signedPreKeyPrefix$keyId',
    );
    if (encoded == null) return null;

    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final spk = SignedPreKey.fromJson(json);

    // Reconstruct with private key if available
    if (json['private_key'] != null) {
      return SignedPreKey(
        keyId: spk.keyId,
        publicKey: spk.publicKey,
        privateKey: base64Decode(json['private_key'] as String),
        signature: spk.signature,
        createdAt: spk.createdAt,
      );
    }
    return spk;
  }

  @override
  Future<void> deleteSignedPreKey(int keyId) async {
    await _secureStorage.delete(key: '$_signedPreKeyPrefix$keyId');
  }

  // =========================================================================
  // One-Time Pre-Keys
  // =========================================================================

  @override
  Future<void> storeOneTimePreKeys(List<OneTimePreKey> preKeys) async {
    // Store each key
    for (final key in preKeys) {
      final data = {
        ...key.toJson(),
        if (key.privateKey != null)
          'private_key': base64Encode(key.privateKey!),
      };
      await _secureStorage.write(
        key: '$_oneTimePreKeyPrefix${key.keyId}',
        value: jsonEncode(data),
      );
    }

    // Update the key IDs list
    final existingIds = await getOneTimePreKeyIds();
    final allIds = {...existingIds, ...preKeys.map((k) => k.keyId)};
    await _secureStorage.write(
      key: _opkIdsKey,
      value: jsonEncode(allIds.toList()),
    );
  }

  @override
  Future<OneTimePreKey?> getOneTimePreKey(int keyId) async {
    final encoded = await _secureStorage.read(
      key: '$_oneTimePreKeyPrefix$keyId',
    );
    if (encoded == null) return null;

    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final opk = OneTimePreKey.fromJson(json);

    if (json['private_key'] != null) {
      return OneTimePreKey(
        keyId: opk.keyId,
        publicKey: opk.publicKey,
        privateKey: base64Decode(json['private_key'] as String),
      );
    }
    return opk;
  }

  @override
  Future<void> deleteOneTimePreKey(int keyId) async {
    await _secureStorage.delete(key: '$_oneTimePreKeyPrefix$keyId');

    // Update the key IDs list
    final ids = await getOneTimePreKeyIds();
    ids.remove(keyId);
    await _secureStorage.write(
      key: _opkIdsKey,
      value: jsonEncode(ids),
    );
  }

  @override
  Future<List<int>> getOneTimePreKeyIds() async {
    final encoded = await _secureStorage.read(key: _opkIdsKey);
    if (encoded == null) return [];
    final list = jsonDecode(encoded) as List<dynamic>;
    return list.map((e) => e as int).toList();
  }

  // =========================================================================
  // Remote Identity Keys
  // =========================================================================

  @override
  Future<void> storeRemoteIdentityKey(
    String userId,
    Uint8List identityKey,
  ) async {
    await _secureStorage.write(
      key: '$_remoteIdentityPrefix$userId',
      value: base64Encode(identityKey),
    );
  }

  @override
  Future<Uint8List?> getRemoteIdentityKey(String userId) async {
    final encoded = await _secureStorage.read(
      key: '$_remoteIdentityPrefix$userId',
    );
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  @override
  Future<bool> hasIdentityKeyChanged(
    String userId,
    Uint8List currentKey,
  ) async {
    final storedKey = await getRemoteIdentityKey(userId);
    if (storedKey == null) return false; // First contact — TOFU
    return !_bytesEqual(storedKey, currentKey);
  }

  // =========================================================================
  // Lifecycle
  // =========================================================================

  @override
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  /// Constant-time byte comparison.
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
