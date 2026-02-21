import 'dart:convert';
import 'dart:typed_data';

import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';

/// Web implementation of [IKeyStoreRepository].
///
/// Uses an in-memory store with AES-256-GCM encryption for persistence.
/// Key material is encrypted with a randomly generated wrapping key
/// and stored as JSON strings (suitable for localStorage/IndexedDB
/// via Dart's platform abstractions).
///
/// Security notes:
/// - On web, there is no hardware-backed keystore
/// - Keys are protected by AES-256-GCM encryption
/// - The wrapping key is generated per session
/// - For production, consider IndexedDB with non-extractable CryptoKey
/// - XSS is the primary threat — enforce strict CSP
///
/// This implementation provides the same interface as [NativeKeyStoreRepository]
/// without depending on `flutter_secure_storage`'s native bindings.
class WebKeyStoreRepository implements IKeyStoreRepository {
  final CryptoProvider _crypto;

  /// In-memory encrypted store.
  /// Keys: storage keys (e.g., 'e2ee_identity_key')
  /// Values: AES-256-GCM encrypted JSON strings
  final Map<String, _EncryptedEntry> _store = {};

  /// AES-256-GCM wrapping key for encrypting stored data.
  late final Uint8List _wrappingKey;

  static const _identityKeyTag = 'e2ee_identity_key';
  static const _signedPreKeyPrefix = 'e2ee_spk_';
  static const _oneTimePreKeyPrefix = 'e2ee_opk_';
  static const _opkIdsKey = 'e2ee_opk_ids';
  static const _remoteIdentityPrefix = 'e2ee_remote_ik_';

  WebKeyStoreRepository({required CryptoProvider crypto}) : _crypto = crypto {
    // Generate wrapping key for this session
    _wrappingKey = SecureRandom.generateAesKey();
  }

  // =========================================================================
  // Encrypted Storage Helpers
  // =========================================================================

  /// Encrypt and store a value.
  Future<void> _write(String key, String value) async {
    final plaintext = Uint8List.fromList(utf8.encode(value));
    final iv = SecureRandom.generateIv();
    final ciphertext = await _crypto.aesGcmEncrypt(
      key: _wrappingKey,
      iv: iv,
      plaintext: plaintext,
    );
    _store[key] = _EncryptedEntry(iv: iv, ciphertext: ciphertext);
  }

  /// Read and decrypt a stored value.
  Future<String?> _read(String key) async {
    final entry = _store[key];
    if (entry == null) return null;

    final plaintext = await _crypto.aesGcmDecrypt(
      key: _wrappingKey,
      iv: entry.iv,
      ciphertext: entry.ciphertext,
    );
    return utf8.decode(plaintext);
  }

  /// Delete a stored value.
  void _delete(String key) {
    _store.remove(key);
  }

  // =========================================================================
  // Identity Key Pair
  // =========================================================================

  @override
  Future<IdentityKeyPair> generateAndStoreIdentityKeyPair() async {
    final dhKeyPair = await _crypto.generateX25519KeyPair();
    final signingKeyPair = await _crypto.generateEd25519KeyPair();
    final registrationId = SecureRandom.generateRegistrationId();

    final identityKeyPair = IdentityKeyPair(
      publicKey: dhKeyPair.publicKey,
      privateKey: dhKeyPair.privateKey,
      signingPublicKey: signingKeyPair.publicKey,
      signingPrivateKey: signingKeyPair.privateKey,
      registrationId: registrationId,
    );

    final data = identityKeyPair.toSecureStorage();
    await _write(_identityKeyTag, jsonEncode(data));

    return identityKeyPair;
  }

  @override
  Future<void> storeIdentityKeyPair(IdentityKeyPair keyPair) async {
    final data = keyPair.toSecureStorage();
    await _write(_identityKeyTag, jsonEncode(data));
  }

  @override
  Future<IdentityKeyPair?> getIdentityKeyPair() async {
    final encoded = await _read(_identityKeyTag);
    if (encoded == null) return null;

    final data = Map<String, String>.from(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    return IdentityKeyPair.fromSecureStorage(data);
  }

  @override
  Future<void> deleteIdentityKeyPair() async {
    _delete(_identityKeyTag);
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

    await _write(
      '$_signedPreKeyPrefix${signedPreKey.keyId}',
      jsonEncode(data),
    );
  }

  @override
  Future<SignedPreKey?> getSignedPreKey(int keyId) async {
    final encoded = await _read('$_signedPreKeyPrefix$keyId');
    if (encoded == null) return null;

    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final spk = SignedPreKey.fromJson(json);

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
    _delete('$_signedPreKeyPrefix$keyId');
  }

  // =========================================================================
  // One-Time Pre-Keys
  // =========================================================================

  @override
  Future<void> storeOneTimePreKeys(List<OneTimePreKey> preKeys) async {
    for (final key in preKeys) {
      final data = {
        ...key.toJson(),
        if (key.privateKey != null)
          'private_key': base64Encode(key.privateKey!),
      };
      await _write('$_oneTimePreKeyPrefix${key.keyId}', jsonEncode(data));
    }

    // Update key IDs list
    final existingIds = await getOneTimePreKeyIds();
    final allIds = {...existingIds, ...preKeys.map((k) => k.keyId)};
    await _write(_opkIdsKey, jsonEncode(allIds.toList()));
  }

  @override
  Future<OneTimePreKey?> getOneTimePreKey(int keyId) async {
    final encoded = await _read('$_oneTimePreKeyPrefix$keyId');
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
    _delete('$_oneTimePreKeyPrefix$keyId');

    final ids = await getOneTimePreKeyIds();
    ids.remove(keyId);
    await _write(_opkIdsKey, jsonEncode(ids));
  }

  @override
  Future<List<int>> getOneTimePreKeyIds() async {
    final encoded = await _read(_opkIdsKey);
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
    await _write(
      '$_remoteIdentityPrefix$userId',
      base64Encode(identityKey),
    );
  }

  @override
  Future<Uint8List?> getRemoteIdentityKey(String userId) async {
    final encoded = await _read('$_remoteIdentityPrefix$userId');
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
    _store.clear();
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

/// An encrypted entry in the web key store.
class _EncryptedEntry {
  final Uint8List iv;
  final Uint8List ciphertext;

  const _EncryptedEntry({required this.iv, required this.ciphertext});
}
