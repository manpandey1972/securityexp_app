import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/web_crypto_provider.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/web_key_store.dart';

void main() {
  late WebKeyStoreRepository keyStore;
  late WebCryptoProvider crypto;

  setUp(() {
    crypto = WebCryptoProvider();
    keyStore = WebKeyStoreRepository(crypto: crypto);
  });

  // ===========================================================================
  // Identity Key Pair
  // ===========================================================================

  group('WebKeyStoreRepository - Identity Key Pair', () {
    test('should generate and store identity key pair', () async {
      final identity = await keyStore.generateAndStoreIdentityKeyPair();

      expect(identity.publicKey.length, 32);
      expect(identity.privateKey.length, 32);
      expect(identity.signingPublicKey.length, 32);
      expect(identity.signingPrivateKey.length, 32);
      expect(identity.registrationId, greaterThan(0));
    });

    test('should retrieve stored identity key pair', () async {
      final original = await keyStore.generateAndStoreIdentityKeyPair();
      final retrieved = await keyStore.getIdentityKeyPair();

      expect(retrieved, isNotNull);
      expect(retrieved!.publicKey, equals(original.publicKey));
      expect(retrieved.privateKey, equals(original.privateKey));
      expect(retrieved.signingPublicKey, equals(original.signingPublicKey));
      expect(retrieved.registrationId, equals(original.registrationId));
    });

    test('should return null when no identity key stored', () async {
      final result = await keyStore.getIdentityKeyPair();
      expect(result, isNull);
    });

    test('should delete identity key pair', () async {
      await keyStore.generateAndStoreIdentityKeyPair();
      await keyStore.deleteIdentityKeyPair();

      final result = await keyStore.getIdentityKeyPair();
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // Signed Pre-Key
  // ===========================================================================

  group('WebKeyStoreRepository - Signed Pre-Key', () {
    test('should store and retrieve signed pre-key', () async {
      final keyPair = await crypto.generateX25519KeyPair();
      final identity = await keyStore.generateAndStoreIdentityKeyPair();
      final signature = await crypto.ed25519Sign(
        identity.signingPrivateKey,
        keyPair.publicKey,
      );

      final spk = SignedPreKey(
        keyId: 42,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
        signature: signature,
        createdAt: DateTime.now(),
      );

      await keyStore.storeSignedPreKey(spk);
      final retrieved = await keyStore.getSignedPreKey(42);

      expect(retrieved, isNotNull);
      expect(retrieved!.keyId, 42);
      expect(retrieved.publicKey, equals(keyPair.publicKey));
      expect(retrieved.privateKey, equals(keyPair.privateKey));
    });

    test('should return null for non-existent SPK', () async {
      final result = await keyStore.getSignedPreKey(999);
      expect(result, isNull);
    });

    test('should delete signed pre-key', () async {
      final keyPair = await crypto.generateX25519KeyPair();
      final spk = SignedPreKey(
        keyId: 1,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
        signature: Uint8List(64),
        createdAt: DateTime.now(),
      );

      await keyStore.storeSignedPreKey(spk);
      await keyStore.deleteSignedPreKey(1);

      final result = await keyStore.getSignedPreKey(1);
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // One-Time Pre-Keys
  // ===========================================================================

  group('WebKeyStoreRepository - One-Time Pre-Keys', () {
    test('should store and retrieve OPKs', () async {
      final kp1 = await crypto.generateX25519KeyPair();
      final kp2 = await crypto.generateX25519KeyPair();

      final opks = [
        OneTimePreKey(keyId: 1, publicKey: kp1.publicKey, privateKey: kp1.privateKey),
        OneTimePreKey(keyId: 2, publicKey: kp2.publicKey, privateKey: kp2.privateKey),
      ];

      await keyStore.storeOneTimePreKeys(opks);

      final retrieved1 = await keyStore.getOneTimePreKey(1);
      expect(retrieved1, isNotNull);
      expect(retrieved1!.publicKey, equals(kp1.publicKey));

      final retrieved2 = await keyStore.getOneTimePreKey(2);
      expect(retrieved2, isNotNull);
      expect(retrieved2!.publicKey, equals(kp2.publicKey));
    });

    test('should track OPK IDs', () async {
      final kp = await crypto.generateX25519KeyPair();
      final opks = [
        OneTimePreKey(keyId: 10, publicKey: kp.publicKey, privateKey: kp.privateKey),
        OneTimePreKey(keyId: 20, publicKey: kp.publicKey, privateKey: kp.privateKey),
      ];

      await keyStore.storeOneTimePreKeys(opks);
      final ids = await keyStore.getOneTimePreKeyIds();

      expect(ids, containsAll([10, 20]));
    });

    test('should delete OPK and update IDs', () async {
      final kp = await crypto.generateX25519KeyPair();
      final opks = [
        OneTimePreKey(keyId: 1, publicKey: kp.publicKey, privateKey: kp.privateKey),
        OneTimePreKey(keyId: 2, publicKey: kp.publicKey, privateKey: kp.privateKey),
      ];

      await keyStore.storeOneTimePreKeys(opks);
      await keyStore.deleteOneTimePreKey(1);

      final remaining = await keyStore.getOneTimePreKeyIds();
      expect(remaining, contains(2));
      expect(remaining, isNot(contains(1)));

      final deleted = await keyStore.getOneTimePreKey(1);
      expect(deleted, isNull);
    });
  });

  // ===========================================================================
  // Remote Identity Keys
  // ===========================================================================

  group('WebKeyStoreRepository - Remote Identity Keys', () {
    test('should store and retrieve remote identity key', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      await keyStore.storeRemoteIdentityKey('user_123', key);

      final retrieved = await keyStore.getRemoteIdentityKey('user_123');
      expect(retrieved, equals(key));
    });

    test('should return null for unknown user', () async {
      final result = await keyStore.getRemoteIdentityKey('unknown');
      expect(result, isNull);
    });

    test('should detect identity key change', () async {
      final key1 = Uint8List.fromList(List.generate(32, (i) => i));
      final key2 = Uint8List.fromList(List.generate(32, (i) => i + 32));

      await keyStore.storeRemoteIdentityKey('user_123', key1);

      final changed = await keyStore.hasIdentityKeyChanged('user_123', key2);
      expect(changed, true);
    });

    test('should not flag unchanged key', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      await keyStore.storeRemoteIdentityKey('user_123', key);

      final changed = await keyStore.hasIdentityKeyChanged('user_123', key);
      expect(changed, false);
    });

    test('should not flag first contact as changed', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final changed = await keyStore.hasIdentityKeyChanged('new_user', key);
      expect(changed, false); // First contact — TOFU
    });
  });

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  group('WebKeyStoreRepository - Lifecycle', () {
    test('should clear all stored data', () async {
      await keyStore.generateAndStoreIdentityKeyPair();
      await keyStore.storeRemoteIdentityKey(
        'user_1',
        Uint8List.fromList(List.generate(32, (i) => i)),
      );

      await keyStore.clearAll();

      final identity = await keyStore.getIdentityKeyPair();
      expect(identity, isNull);

      final remote = await keyStore.getRemoteIdentityKey('user_1');
      expect(remote, isNull);
    });
  });
}
