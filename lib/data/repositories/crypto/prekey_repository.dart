import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';

/// Minimum number of OPKs before triggering replenishment.
const _opkReplenishThreshold = 20;

/// Number of OPKs to generate per batch.
const _opkBatchSize = 100;

/// Maximum number of devices per user.
const _maxDevicesPerUser = 5;

/// Repository for managing PreKeyBundles in Firestore.
///
/// Handles:
/// - Publishing local device's public keys to Firestore
/// - Fetching remote users' PreKeyBundles for X3DH
/// - OPK consumption and replenishment
/// - Signed pre-key rotation
/// - Device registration and deregistration
class PreKeyRepository {
  final FirebaseFirestore _firestore;
  final IKeyStoreRepository _keyStore;
  final CryptoProvider _crypto;

  // ignore: unused_field
  static const _tag = 'PreKeyRepository';

  PreKeyRepository({
    required FirebaseFirestore firestore,
    required IKeyStoreRepository keyStore,
    required CryptoProvider crypto,
  })  : _firestore = firestore,
        _keyStore = keyStore,
        _crypto = crypto;

  /// Reference to a user's devices collection.
  CollectionReference<Map<String, dynamic>> _devicesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('devices');

  // =========================================================================
  // Device Registration
  // =========================================================================

  /// Register this device's E2EE keys with Firestore.
  ///
  /// Generates identity keys, signed pre-key, and OPKs,
  /// then publishes the public parts to Firestore.
  ///
  /// Throws if user already has [_maxDevicesPerUser] devices.
  Future<({IdentityKeyPair identity, String deviceId})> registerDevice({
    required String userId,
    required String deviceId,
    required String deviceName,
  }) async {
    // 1. Check device limit
    final existingDevices = await _devicesRef(userId).get();
    if (existingDevices.docs.length >= _maxDevicesPerUser) {
      throw StateError(
        'Maximum $_maxDevicesPerUser devices reached. '
        'Please remove a device before adding a new one.',
      );
    }

    // 2. Generate identity key pair
    final identity = await _keyStore.generateAndStoreIdentityKeyPair();

    // 3. Generate signed pre-key
    final signedPreKey = await _generateSignedPreKey(identity);

    // 4. Generate one-time pre-keys
    final oneTimePreKeys = await _generateOneTimePreKeys(_opkBatchSize);

    // 5. Build and publish PreKeyBundle
    final bundle = PreKeyBundle(
      userId: userId,
      deviceId: deviceId,
      identityKey: identity.publicKey,
      signingKey: identity.signingPublicKey,
      signedPreKey: signedPreKey,
      oneTimePreKeys: oneTimePreKeys.map((k) => OneTimePreKey(
        keyId: k.keyId,
        publicKey: k.publicKey,
      )).toList(),
      registrationId: identity.registrationId,
      deviceName: deviceName,
    );

    await _devicesRef(userId).doc(deviceId).set({
      ...bundle.toJson(),
      'created_at': FieldValue.serverTimestamp(),
      'last_active': FieldValue.serverTimestamp(),
    });

    return (identity: identity, deviceId: deviceId);
  }

  /// Deregister (revoke) a device, removing its keys from Firestore.
  Future<void> deregisterDevice({
    required String userId,
    required String deviceId,
  }) async {
    await _devicesRef(userId).doc(deviceId).delete();
  }

  // =========================================================================
  // PreKeyBundle Fetch
  // =========================================================================

  /// Fetch a remote user's PreKeyBundle for X3DH key exchange.
  ///
  /// Returns the bundle for the specified device, or the first active
  /// device if no deviceId is specified.
  ///
  /// Atomically consumes one OPK from the bundle (removes it from Firestore).
  Future<PreKeyBundle?> fetchAndConsumePreKeyBundle({
    required String userId,
    String? deviceId,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> doc;

    if (deviceId != null) {
      doc = await _devicesRef(userId).doc(deviceId).get();
      if (!doc.exists) return null;
    } else {
      // Get the most recently active device
      final query = await _devicesRef(userId)
          .orderBy('last_active', descending: true)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      doc = query.docs.first;
    }

    final data = doc.data();
    if (data == null) return null;

    final bundle = PreKeyBundle.fromJson({...data, 'device_id': doc.id});

    // Atomically consume one OPK
    if (bundle.oneTimePreKeys.isNotEmpty) {
      final consumedOpk = bundle.oneTimePreKeys.first;
      await _devicesRef(userId).doc(doc.id).update({
        'one_time_pre_keys': FieldValue.arrayRemove([consumedOpk.toJson()]),
      });

      // Return bundle with only the consumed OPK
      return bundle.copyWith(
        oneTimePreKeys: [consumedOpk],
      );
    }

    // No OPKs available — return bundle without OPKs (X3DH still works, reduced forward secrecy)
    return bundle.copyWith(oneTimePreKeys: []);
  }

  /// Fetch a remote user's PreKeyBundle WITHOUT consuming an OPK.
  /// Used for identity key verification and safety number computation.
  Future<PreKeyBundle?> fetchPreKeyBundle({
    required String userId,
    String? deviceId,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> doc;

    if (deviceId != null) {
      doc = await _devicesRef(userId).doc(deviceId).get();
    } else {
      final query = await _devicesRef(userId)
          .orderBy('last_active', descending: true)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      doc = query.docs.first;
    }

    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;

    return PreKeyBundle.fromJson({...data, 'device_id': doc.id});
  }

  /// Get all registered devices for a user.
  Future<List<PreKeyBundle>> getDevices(String userId) async {
    final snapshot = await _devicesRef(userId).get();
    return snapshot.docs
        .map((doc) => PreKeyBundle.fromJson({...doc.data(), 'device_id': doc.id}))
        .toList();
  }

  // =========================================================================
  // Signed Pre-Key Rotation
  // =========================================================================

  /// Rotate the signed pre-key.
  ///
  /// Generates a new SPK, publishes it to Firestore, and stores the
  /// private key locally. The old SPK is kept for a grace period
  /// (48 hours) to handle in-flight messages.
  Future<void> rotateSignedPreKey({
    required String userId,
    required String deviceId,
  }) async {
    final identity = await _keyStore.getIdentityKeyPair();
    if (identity == null) {
      throw StateError('No identity key pair found for signed pre-key rotation');
    }

    final newSpk = await _generateSignedPreKey(identity);

    // Update Firestore with new SPK
    await _devicesRef(userId).doc(deviceId).update({
      'signed_pre_key': newSpk.toJson(),
      'last_active': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================================
  // OPK Replenishment
  // =========================================================================

  /// Check OPK count and replenish if below threshold.
  ///
  /// Returns true if replenishment was performed.
  Future<bool> replenishOneTimePreKeysIfNeeded({
    required String userId,
    required String deviceId,
  }) async {
    final doc = await _devicesRef(userId).doc(deviceId).get();
    if (!doc.exists) return false;

    final data = doc.data();
    if (data == null) return false;

    final opkList = data['one_time_pre_keys'] as List<dynamic>? ?? [];
    if (opkList.length >= _opkReplenishThreshold) return false;

    // Generate new batch of OPKs
    final newOpks = await _generateOneTimePreKeys(_opkBatchSize);
    final publicOpks = newOpks.map((k) => OneTimePreKey(
      keyId: k.keyId,
      publicKey: k.publicKey,
    )).toList();

    // Append new OPKs to Firestore
    await _devicesRef(userId).doc(deviceId).update({
      'one_time_pre_keys': FieldValue.arrayUnion(
        publicOpks.map((k) => k.toJson()).toList(),
      ),
      'last_active': FieldValue.serverTimestamp(),
    });

    return true;
  }

  // =========================================================================
  // Device Activity
  // =========================================================================

  /// Update last active timestamp for a device.
  Future<void> updateLastActive({
    required String userId,
    required String deviceId,
  }) async {
    await _devicesRef(userId).doc(deviceId).update({
      'last_active': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================================
  // Key Generation Helpers
  // =========================================================================

  /// Generate a signed pre-key using the identity key for signing.
  Future<SignedPreKey> _generateSignedPreKey(
    IdentityKeyPair identity,
  ) async {
    final keyPair = await _crypto.generateX25519KeyPair();
    final keyId = SecureRandom.generatePreKeyId();

    // Sign the public key with Ed25519 identity signing key
    final signature = await _crypto.ed25519Sign(
      identity.signingPrivateKey,
      keyPair.publicKey,
    );

    final spk = SignedPreKey(
      keyId: keyId,
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
      signature: signature,
      createdAt: DateTime.now(),
    );

    // Store private key locally
    await _keyStore.storeSignedPreKey(spk);

    return spk;
  }

  /// Generate a batch of one-time pre-keys.
  Future<List<OneTimePreKey>> _generateOneTimePreKeys(int count) async {
    final keys = <OneTimePreKey>[];

    for (var i = 0; i < count; i++) {
      final keyPair = await _crypto.generateX25519KeyPair();
      final keyId = SecureRandom.generatePreKeyId();

      keys.add(OneTimePreKey(
        keyId: keyId,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
      ));
    }

    // Store private keys locally
    await _keyStore.storeOneTimePreKeys(keys);

    return keys;
  }
}
