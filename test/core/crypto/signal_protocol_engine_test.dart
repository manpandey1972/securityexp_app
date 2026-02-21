import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/crypto/native_crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/signal_protocol_engine.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

void main() {
  late NativeCryptoProvider crypto;
  late SignalProtocolEngine engine;

  setUp(() {
    crypto = NativeCryptoProvider();
    engine = SignalProtocolEngine(crypto);
  });

  /// Helper to generate a full identity key pair (X25519 + Ed25519).
  Future<IdentityKeyPair> generateIdentity() async {
    final x25519 = await crypto.generateX25519KeyPair();
    final ed25519 = await crypto.generateEd25519KeyPair();
    return IdentityKeyPair(
      publicKey: x25519.publicKey,
      privateKey: x25519.privateKey,
      signingPublicKey: ed25519.publicKey,
      signingPrivateKey: ed25519.privateKey,
      registrationId: 12345,
    );
  }

  /// Helper to generate a signed pre-key.
  Future<SignedPreKey> generateSignedPreKey(
    IdentityKeyPair identity,
    int keyId,
  ) async {
    final keyPair = await crypto.generateX25519KeyPair();
    final signature = await crypto.ed25519Sign(
      identity.signingPrivateKey,
      keyPair.publicKey,
    );
    return SignedPreKey(
      keyId: keyId,
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
      signature: signature,
      createdAt: DateTime.now(),
    );
  }

  /// Helper to generate one-time pre-keys.
  Future<List<OneTimePreKey>> generateOneTimePreKeys(
    int startId,
    int count,
  ) async {
    final keys = <OneTimePreKey>[];
    for (var i = 0; i < count; i++) {
      final keyPair = await crypto.generateX25519KeyPair();
      keys.add(OneTimePreKey(
        keyId: startId + i,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
      ));
    }
    return keys;
  }

  /// Helper to set up a full X3DH session between Alice and Bob,
  /// returning both session states.
  Future<({SessionState aliceSession, SessionState bobSession})>
      setupSession() async {
    final aliceIdentity = await generateIdentity();
    final bobIdentity = await generateIdentity();
    final bobSpk = await generateSignedPreKey(bobIdentity, 1);
    final bobOpks = await generateOneTimePreKeys(1, 5);

    final bobBundle = PreKeyBundle(
      userId: 'bob',
      deviceId: 'bob_device',
      identityKey: bobIdentity.publicKey,
      signingKey: bobIdentity.signingPublicKey,
      signedPreKey: bobSpk,
      oneTimePreKeys: bobOpks,
      registrationId: bobIdentity.registrationId,
      deviceName: 'Bob Phone',
    );

    final initiatorResult = await engine.performX3dhInitiator(
      localIdentity: aliceIdentity,
      remoteBundle: bobBundle,
      remoteUserId: 'bob',
    );

    final consumedOpk = bobOpks.firstWhere(
      (k) => k.keyId == initiatorResult.initialMessage.oneTimePreKeyId,
    );

    final bobSession = await engine.performX3dhResponder(
      localIdentity: bobIdentity,
      initialMsg: initiatorResult.initialMessage,
      localSignedPreKey: bobSpk,
      consumedOpk: consumedOpk,
    );

    return (
      aliceSession: initiatorResult.session,
      bobSession: bobSession.copyWith(
        remoteUserId: 'alice',
        remoteDeviceId: 'alice_device',
      ),
    );
  }

  // ===========================================================================
  // X3DH Key Agreement
  // ===========================================================================

  group('X3DH Key Agreement', () {
    test('should complete X3DH handshake with OPK', () async {
      // Bob publishes his keys
      final bobIdentity = await generateIdentity();
      final bobSpk = await generateSignedPreKey(bobIdentity, 1);
      final bobOpks = await generateOneTimePreKeys(1, 5);

      final bobBundle = PreKeyBundle(
        userId: 'bob_123',
        deviceId: 'bob_device_1',
        identityKey: bobIdentity.publicKey,
        signingKey: bobIdentity.signingPublicKey,
        signedPreKey: bobSpk,
        oneTimePreKeys: bobOpks,
        registrationId: bobIdentity.registrationId,
        deviceName: 'Bob Phone',
      );

      // Alice initiates X3DH
      final aliceIdentity = await generateIdentity();

      final initiatorResult = await engine.performX3dhInitiator(
        localIdentity: aliceIdentity,
        remoteBundle: bobBundle,
        remoteUserId: 'bob_123',
      );

      expect(initiatorResult.session.rootKey.length, 32);
      expect(initiatorResult.initialMessage.identityKey, isNotEmpty);
      expect(initiatorResult.initialMessage.ephemeralKey, isNotEmpty);
      expect(initiatorResult.initialMessage.signedPreKeyId, 1);
      expect(initiatorResult.initialMessage.oneTimePreKeyId, bobOpks.first.keyId);

      // Bob responds (look up consumed OPK)
      final consumedOpk = bobOpks.firstWhere(
        (k) => k.keyId == initiatorResult.initialMessage.oneTimePreKeyId,
      );

      final bobSession = await engine.performX3dhResponder(
        localIdentity: bobIdentity,
        initialMsg: initiatorResult.initialMessage,
        localSignedPreKey: bobSpk,
        consumedOpk: consumedOpk,
      );

      expect(bobSession.rootKey.length, 32);
      // Per Signal spec, CKr is null until Bob receives Alice's first message
      expect(bobSession.receivingChainKey, isNull);
    });

    test('should complete X3DH handshake without OPK', () async {
      final bobIdentity = await generateIdentity();
      final bobSpk = await generateSignedPreKey(bobIdentity, 1);

      final bobBundle = PreKeyBundle(
        userId: 'bob_123',
        deviceId: 'bob_device_1',
        identityKey: bobIdentity.publicKey,
        signingKey: bobIdentity.signingPublicKey,
        signedPreKey: bobSpk,
        oneTimePreKeys: [], // No OPKs available
        registrationId: bobIdentity.registrationId,
        deviceName: 'Bob Phone',
      );

      final aliceIdentity = await generateIdentity();

      final initiatorResult = await engine.performX3dhInitiator(
        localIdentity: aliceIdentity,
        remoteBundle: bobBundle,
        remoteUserId: 'bob_123',
      );

      expect(initiatorResult.initialMessage.oneTimePreKeyId, isNull);

      final bobSession = await engine.performX3dhResponder(
        localIdentity: bobIdentity,
        initialMsg: initiatorResult.initialMessage,
        localSignedPreKey: bobSpk,
        consumedOpk: null,
      );

      expect(bobSession.rootKey.length, 32);
    });

    test('should fail X3DH with invalid SPK signature', () async {
      final bobIdentity = await generateIdentity();
      final bobSpk = await generateSignedPreKey(bobIdentity, 1);

      // Tamper with the SPK signature
      final tamperedSignature = Uint8List.fromList(bobSpk.signature);
      tamperedSignature[0] ^= 0xFF;

      final tamperedSpk = SignedPreKey(
        keyId: bobSpk.keyId,
        publicKey: bobSpk.publicKey,
        privateKey: bobSpk.privateKey,
        signature: tamperedSignature,
        createdAt: bobSpk.createdAt,
      );

      final bobBundle = PreKeyBundle(
        userId: 'bob_123',
        deviceId: 'bob_device_1',
        identityKey: bobIdentity.publicKey,
        signingKey: bobIdentity.signingPublicKey,
        signedPreKey: tamperedSpk,
        oneTimePreKeys: [],
        registrationId: bobIdentity.registrationId,
        deviceName: 'Bob Phone',
      );

      final aliceIdentity = await generateIdentity();

      expect(
        () => engine.performX3dhInitiator(
          localIdentity: aliceIdentity,
          remoteBundle: bobBundle,
          remoteUserId: 'bob_123',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ===========================================================================
  // Double Ratchet Encrypt/Decrypt
  // ===========================================================================

  group('Double Ratchet', () {
    test('Alice should encrypt and Bob should decrypt first message', () async {
      final (:aliceSession, :bobSession) = await setupSession();

      final plaintext = Uint8List.fromList(
        utf8.encode('Hello Bob! This is our first encrypted message.'),
      );

      // Alice encrypts
      final encryptResult = await engine.encryptMessage(
        aliceSession,
        plaintext,
      );

      expect(encryptResult.ciphertext.length, greaterThan(16));
      expect(encryptResult.header.messageNumber, 0);
      expect(encryptResult.updatedSession.sendMessageNumber, 1);

      // Bob decrypts
      final decryptResult = await engine.decryptMessage(
        bobSession,
        encryptResult.ciphertext,
        encryptResult.header,
      );

      expect(decryptResult.plaintext, equals(plaintext));
      expect(
        utf8.decode(decryptResult.plaintext),
        'Hello Bob! This is our first encrypted message.',
      );
    });

    test('should handle multiple messages in sequence', () async {
      final (:aliceSession, :bobSession) = await setupSession();

      var currentAliceSession = aliceSession;
      var currentBobSession = bobSession;

      for (var i = 0; i < 10; i++) {
        final plaintext = Uint8List.fromList(
          utf8.encode('Message $i from Alice'),
        );

        final encResult = await engine.encryptMessage(
          currentAliceSession,
          plaintext,
        );

        expect(encResult.header.messageNumber, i);

        final decResult = await engine.decryptMessage(
          currentBobSession,
          encResult.ciphertext,
          encResult.header,
        );

        expect(utf8.decode(decResult.plaintext), 'Message $i from Alice');

        currentAliceSession = encResult.updatedSession;
        currentBobSession = decResult.updatedSession;
      }
    });

    test('should produce unique ciphertext for same plaintext', () async {
      final (:aliceSession, bobSession: _) = await setupSession();

      final plaintext = Uint8List.fromList(utf8.encode('Same message'));

      final enc1 = await engine.encryptMessage(aliceSession, plaintext);
      final enc2 = await engine.encryptMessage(
        enc1.updatedSession,
        plaintext,
      );

      // Different message keys should produce different ciphertext
      expect(enc1.ciphertext, isNot(equals(enc2.ciphertext)));
    });

    test('should fail encryption without sending chain key', () async {
      final session = SessionState(
        remoteUserId: 'test',
        remoteDeviceId: 'test_device',
        dhPrivateKey: Uint8List(32),
        dhPublicKey: Uint8List(32),
        rootKey: Uint8List(32),
        sendingChainKey: null, // No sending chain
        remoteIdentityKey: Uint8List(32),
        lastActive: DateTime.now(),
      );

      expect(
        () => engine.encryptMessage(
          session,
          Uint8List.fromList(utf8.encode('test')),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('should fail decryption with tampered ciphertext', () async {
      final (:aliceSession, :bobSession) = await setupSession();

      final plaintext = Uint8List.fromList(utf8.encode('Tamper test'));

      final encResult = await engine.encryptMessage(aliceSession, plaintext);

      // Tamper with ciphertext
      final tampered = Uint8List.fromList(encResult.ciphertext);
      tampered[0] ^= 0xFF;

      expect(
        () => engine.decryptMessage(
          bobSession,
          tampered,
          encResult.header,
        ),
        throwsA(anything),
      );
    });
  });

  // ===========================================================================
  // Session State Serialization
  // ===========================================================================

  group('SessionState serialization', () {
    test('should serialize and deserialize round-trip', () async {
      final (:aliceSession, bobSession: _) = await setupSession();

      final serialized = aliceSession.serialize();
      final deserialized = SessionState.deserialize(serialized);

      expect(deserialized.remoteUserId, equals(aliceSession.remoteUserId));
      expect(deserialized.rootKey, equals(aliceSession.rootKey));
      expect(deserialized.dhPublicKey, equals(aliceSession.dhPublicKey));
      expect(deserialized.dhPrivateKey, equals(aliceSession.dhPrivateKey));
      expect(
        deserialized.sendMessageNumber,
        equals(aliceSession.sendMessageNumber),
      );
    });

    test('should preserve skipped message keys', () {
      final skipped = <String, Uint8List>{
        'key1:0': Uint8List.fromList(List.generate(32, (i) => i)),
        'key2:1': Uint8List.fromList(List.generate(32, (i) => i + 32)),
      };

      final session = SessionState(
        remoteUserId: 'test',
        remoteDeviceId: 'device',
        dhPrivateKey: Uint8List(32),
        dhPublicKey: Uint8List(32),
        rootKey: Uint8List(32),
        remoteIdentityKey: Uint8List(32),
        skippedMessageKeys: skipped,
        lastActive: DateTime.now(),
      );

      final serialized = session.serialize();
      final deserialized = SessionState.deserialize(serialized);

      expect(deserialized.skippedMessageKeys.length, 2);
      expect(
        deserialized.skippedMessageKeys['key1:0'],
        equals(skipped['key1:0']),
      );
    });
  });
}

/// Helper to set up a session (for use in a helper isolated from main).
Future<({SessionState aliceSession, SessionState bobSession})>
    createTestSession(
  NativeCryptoProvider crypto,
  SignalProtocolEngine engine,
) async {
  final aliceX25519 = await crypto.generateX25519KeyPair();
  final aliceEd25519 = await crypto.generateEd25519KeyPair();
  final aliceIdentity = IdentityKeyPair(
    publicKey: aliceX25519.publicKey,
    privateKey: aliceX25519.privateKey,
    signingPublicKey: aliceEd25519.publicKey,
    signingPrivateKey: aliceEd25519.privateKey,
    registrationId: 1,
  );

  final bobX25519 = await crypto.generateX25519KeyPair();
  final bobEd25519 = await crypto.generateEd25519KeyPair();
  final bobIdentity = IdentityKeyPair(
    publicKey: bobX25519.publicKey,
    privateKey: bobX25519.privateKey,
    signingPublicKey: bobEd25519.publicKey,
    signingPrivateKey: bobEd25519.privateKey,
    registrationId: 2,
  );

  final spkKeyPair = await crypto.generateX25519KeyPair();
  final spkSig = await crypto.ed25519Sign(
    bobIdentity.signingPrivateKey,
    spkKeyPair.publicKey,
  );
  final bobSpk = SignedPreKey(
    keyId: 1,
    publicKey: spkKeyPair.publicKey,
    privateKey: spkKeyPair.privateKey,
    signature: spkSig,
    createdAt: DateTime.now(),
  );

  final opkKeyPair = await crypto.generateX25519KeyPair();
  final bobOpk = OneTimePreKey(
    keyId: 1,
    publicKey: opkKeyPair.publicKey,
    privateKey: opkKeyPair.privateKey,
  );

  final bobBundle = PreKeyBundle(
    userId: 'bob',
    deviceId: 'bob_dev',
    identityKey: bobIdentity.publicKey,
    signingKey: bobIdentity.signingPublicKey,
    signedPreKey: bobSpk,
    oneTimePreKeys: [bobOpk],
    registrationId: 2,
    deviceName: 'Bob Phone',
  );

  final result = await engine.performX3dhInitiator(
    localIdentity: aliceIdentity,
    remoteBundle: bobBundle,
    remoteUserId: 'bob',
  );

  final bobSession = await engine.performX3dhResponder(
    localIdentity: bobIdentity,
    initialMsg: result.initialMessage,
    localSignedPreKey: bobSpk,
    consumedOpk: bobOpk,
  );

  return (
    aliceSession: result.session,
    bobSession: bobSession.copyWith(
      remoteUserId: 'alice',
      remoteDeviceId: 'alice_dev',
    ),
  );
}
