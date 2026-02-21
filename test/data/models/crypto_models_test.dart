import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

void main() {
  // ===========================================================================
  // IdentityKeyPair
  // ===========================================================================

  group('IdentityKeyPair', () {
    final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
    final privateKey = Uint8List.fromList(List.generate(32, (i) => i + 32));
    final signingPublicKey =
        Uint8List.fromList(List.generate(32, (i) => i + 64));
    final signingPrivateKey =
        Uint8List.fromList(List.generate(32, (i) => i + 96));

    test('should create with required fields', () {
      final identity = IdentityKeyPair(
        publicKey: publicKey,
        privateKey: privateKey,
        signingPublicKey: signingPublicKey,
        signingPrivateKey: signingPrivateKey,
        registrationId: 42,
      );

      expect(identity.publicKey, equals(publicKey));
      expect(identity.privateKey, equals(privateKey));
      expect(identity.registrationId, 42);
    });

    test('should serialize to secure storage and back', () {
      final identity = IdentityKeyPair(
        publicKey: publicKey,
        privateKey: privateKey,
        signingPublicKey: signingPublicKey,
        signingPrivateKey: signingPrivateKey,
        registrationId: 42,
      );

      final stored = identity.toSecureStorage();
      final restored = IdentityKeyPair.fromSecureStorage(stored);

      expect(restored.publicKey, equals(identity.publicKey));
      expect(restored.privateKey, equals(identity.privateKey));
      expect(restored.signingPublicKey, equals(identity.signingPublicKey));
      expect(restored.signingPrivateKey, equals(identity.signingPrivateKey));
      expect(restored.registrationId, equals(identity.registrationId));
    });

    test('should export public JSON without private keys', () {
      final identity = IdentityKeyPair(
        publicKey: publicKey,
        privateKey: privateKey,
        signingPublicKey: signingPublicKey,
        signingPrivateKey: signingPrivateKey,
        registrationId: 42,
      );

      final json = identity.toPublicJson();

      expect(json.containsKey('identity_key'), true);
      expect(json.containsKey('signing_key'), true);
      expect(json.containsKey('registration_id'), true);
      expect(json.containsKey('private_key'), false);
      expect(json.containsKey('signing_private_key'), false);
    });

    test('should support Equatable equality', () {
      final a = IdentityKeyPair(
        publicKey: publicKey,
        privateKey: privateKey,
        signingPublicKey: signingPublicKey,
        signingPrivateKey: signingPrivateKey,
        registrationId: 42,
      );

      final b = IdentityKeyPair(
        publicKey: Uint8List.fromList(publicKey),
        privateKey: Uint8List.fromList(privateKey),
        signingPublicKey: Uint8List.fromList(signingPublicKey),
        signingPrivateKey: Uint8List.fromList(signingPrivateKey),
        registrationId: 42,
      );

      expect(a, equals(b));
    });
  });

  // ===========================================================================
  // SignedPreKey
  // ===========================================================================

  group('SignedPreKey', () {
    test('should serialize to JSON and back', () {
      final spk = SignedPreKey(
        keyId: 1,
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        signature: Uint8List.fromList(List.generate(64, (i) => i)),
        createdAt: DateTime.utc(2025, 1, 15, 12, 0, 0),
      );

      final json = spk.toJson();
      final restored = SignedPreKey.fromJson(json);

      expect(restored.keyId, 1);
      expect(restored.publicKey.length, 32);
      expect(restored.signature.length, 64);
    });

    test('should not include private key in JSON', () {
      final spk = SignedPreKey(
        keyId: 1,
        publicKey: Uint8List(32),
        privateKey: Uint8List(32),
        signature: Uint8List(64),
        createdAt: DateTime.now(),
      );

      final json = spk.toJson();
      expect(json.containsKey('private_key'), false);
    });
  });

  // ===========================================================================
  // OneTimePreKey
  // ===========================================================================

  group('OneTimePreKey', () {
    test('should serialize to JSON and back', () {
      final opk = OneTimePreKey(
        keyId: 42,
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
      );

      final json = opk.toJson();
      final restored = OneTimePreKey.fromJson(json);

      expect(restored.keyId, 42);
      expect(restored.publicKey.length, 32);
    });
  });

  // ===========================================================================
  // PreKeyBundle
  // ===========================================================================

  group('PreKeyBundle', () {
    test('should serialize to JSON and back', () {
      final bundle = PreKeyBundle(
        userId: 'user_123',
        deviceId: 'device_abc',
        identityKey: Uint8List.fromList(List.generate(32, (i) => i)),
        signingKey: Uint8List.fromList(List.generate(32, (i) => i + 32)),
        signedPreKey: SignedPreKey(
          keyId: 1,
          publicKey: Uint8List.fromList(List.generate(32, (i) => i + 64)),
          signature: Uint8List.fromList(List.generate(64, (i) => i)),
          createdAt: DateTime.utc(2025, 1, 15),
        ),
        oneTimePreKeys: [
          OneTimePreKey(
            keyId: 1,
            publicKey: Uint8List.fromList(List.generate(32, (i) => i + 96)),
          ),
          OneTimePreKey(
            keyId: 2,
            publicKey: Uint8List.fromList(List.generate(32, (i) => i + 128)),
          ),
        ],
        registrationId: 9999,
        deviceName: 'Test Phone',
      );

      final json = bundle.toJson();
      final restored = PreKeyBundle.fromJson(json);

      expect(restored.userId, 'user_123');
      expect(restored.deviceId, 'device_abc');
      expect(restored.identityKey.length, 32);
      expect(restored.signedPreKey.keyId, 1);
      expect(restored.oneTimePreKeys.length, 2);
      expect(restored.registrationId, 9999);
      expect(restored.deviceName, 'Test Phone');
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'identity_key': base64Encode(Uint8List(32)),
        'signing_key': base64Encode(Uint8List(32)),
        'signed_pre_key': {
          'key_id': 1,
          'public_key': base64Encode(Uint8List(32)),
          'signature': base64Encode(Uint8List(64)),
        },
      };

      final bundle = PreKeyBundle.fromJson(json);

      expect(bundle.userId, '');
      expect(bundle.oneTimePreKeys, isEmpty);
      expect(bundle.attestation, isNull);
    });

    test('should support copyWith', () {
      final bundle = PreKeyBundle(
        userId: 'user_1',
        deviceId: 'device_1',
        identityKey: Uint8List(32),
        signingKey: Uint8List(32),
        signedPreKey: SignedPreKey(
          keyId: 1,
          publicKey: Uint8List(32),
          signature: Uint8List(64),
          createdAt: DateTime.now(),
        ),
        oneTimePreKeys: [],
        registrationId: 1,
        deviceName: 'Phone',
      );

      final modified = bundle.copyWith(
        deviceName: 'Tablet',
        registrationId: 2,
      );

      expect(modified.deviceName, 'Tablet');
      expect(modified.registrationId, 2);
      expect(modified.userId, 'user_1'); // unchanged
    });
  });

  // ===========================================================================
  // RatchetHeader
  // ===========================================================================

  group('RatchetHeader', () {
    test('should serialize to JSON and back', () {
      final header = RatchetHeader(
        dhPublicKey: base64Encode(Uint8List.fromList(List.generate(32, (i) => i))),
        messageNumber: 5,
        previousChainLength: 3,
      );

      final json = header.toJson();
      final restored = RatchetHeader.fromJson(json);

      expect(restored.dhPublicKey, equals(header.dhPublicKey));
      expect(restored.messageNumber, 5);
      expect(restored.previousChainLength, 3);
    });

    test('should produce deterministic AAD bytes', () {
      final header = RatchetHeader(
        dhPublicKey: 'testKey123',
        messageNumber: 42,
        previousChainLength: 10,
      );

      final aad1 = header.toAad();
      final aad2 = header.toAad();

      expect(aad1, equals(aad2));
    });

    test('should decode dhPublicKeyBytes', () {
      final keyBytes = Uint8List.fromList(List.generate(32, (i) => i));
      final header = RatchetHeader(
        dhPublicKey: base64Encode(keyBytes),
        messageNumber: 0,
        previousChainLength: 0,
      );

      expect(header.dhPublicKeyBytes, equals(keyBytes));
    });
  });

  // ===========================================================================
  // SessionState
  // ===========================================================================

  group('SessionState', () {
    final dhPriv = Uint8List.fromList(List.generate(32, (i) => i));
    final dhPub = Uint8List.fromList(List.generate(32, (i) => i + 32));
    final rootKey = Uint8List.fromList(List.generate(32, (i) => i + 64));
    final remoteIk = Uint8List.fromList(List.generate(32, (i) => i + 96));
    final now = DateTime.utc(2025, 6, 15, 12, 0, 0);

    test('should serialize and deserialize round-trip', () {
      final session = SessionState(
        remoteUserId: 'user_remote',
        remoteDeviceId: 'device_remote',
        dhPrivateKey: dhPriv,
        dhPublicKey: dhPub,
        rootKey: rootKey,
        sendingChainKey: Uint8List(32),
        receivingChainKey: Uint8List(32),
        sendMessageNumber: 5,
        receiveMessageNumber: 3,
        previousSendingChainLength: 2,
        remoteIdentityKey: remoteIk,
        lastActive: now,
      );

      final serialized = session.serialize();
      final deserialized = SessionState.deserialize(serialized);

      expect(deserialized.remoteUserId, 'user_remote');
      expect(deserialized.remoteDeviceId, 'device_remote');
      expect(deserialized.sendMessageNumber, 5);
      expect(deserialized.receiveMessageNumber, 3);
      expect(deserialized.previousSendingChainLength, 2);
      expect(deserialized.dhPrivateKey, equals(dhPriv));
    });

    test('should handle null optional fields', () {
      final session = SessionState(
        remoteUserId: 'user',
        remoteDeviceId: 'device',
        dhPrivateKey: dhPriv,
        dhPublicKey: dhPub,
        rootKey: rootKey,
        remoteIdentityKey: remoteIk,
        lastActive: now,
      );

      final serialized = session.serialize();
      expect(serialized.containsKey('sending_chain_key'), false);
      expect(serialized.containsKey('receiving_chain_key'), false);
      expect(serialized.containsKey('remote_dh_public_key'), false);

      final deserialized = SessionState.deserialize(serialized);
      expect(deserialized.sendingChainKey, isNull);
      expect(deserialized.receivingChainKey, isNull);
      expect(deserialized.remoteDhPublicKey, isNull);
    });

    test('copyWith should override specified fields', () {
      final session = SessionState(
        remoteUserId: 'user',
        remoteDeviceId: 'device',
        dhPrivateKey: dhPriv,
        dhPublicKey: dhPub,
        rootKey: rootKey,
        sendMessageNumber: 5,
        remoteIdentityKey: remoteIk,
        lastActive: now,
      );

      final updated = session.copyWith(
        sendMessageNumber: 6,
        sendingChainKey: Uint8List(32),
      );

      expect(updated.sendMessageNumber, 6);
      expect(updated.sendingChainKey, isNotNull);
      expect(updated.remoteUserId, 'user'); // unchanged
    });
  });

  // ===========================================================================
  // DecryptedContent
  // ===========================================================================

  group('DecryptedContent', () {
    test('should serialize to bytes and back for text', () {
      final content = DecryptedContent(
        text: 'Hello, encrypted world!',
      );

      final bytes = content.toBytes();
      expect(bytes.isNotEmpty, true);

      final restored = DecryptedContent.fromBytes(bytes);
      expect(restored.text, 'Hello, encrypted world!');
    });

    test('should handle media fields', () {
      final content = DecryptedContent(
        text: 'Check this out',
        mediaUrl: 'gs://bucket/encrypted_file.bin',
        mediaType: 'image/jpeg',
        mediaSize: 1024000,
        fileName: 'photo.jpg',
      );

      final bytes = content.toBytes();
      final restored = DecryptedContent.fromBytes(bytes);

      expect(restored.text, 'Check this out');
      expect(restored.mediaUrl, 'gs://bucket/encrypted_file.bin');
      expect(restored.mediaType, 'image/jpeg');
      expect(restored.mediaSize, 1024000);
      expect(restored.fileName, 'photo.jpg');
    });

    test('should handle reply metadata', () {
      final content = DecryptedContent(
        text: 'I agree!',
        replyToMessageId: 'msg_original_123',
        metadata: {'reaction': 'thumbsup'},
      );

      final bytes = content.toBytes();
      final restored = DecryptedContent.fromBytes(bytes);

      expect(restored.replyToMessageId, 'msg_original_123');
      expect(restored.metadata?['reaction'], 'thumbsup');
    });
  });
}
