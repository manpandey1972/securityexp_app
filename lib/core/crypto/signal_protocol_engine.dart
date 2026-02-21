import 'dart:convert';
import 'dart:typed_data';

import 'package:securityexperts_app/core/crypto/aes_gcm_cipher.dart';
import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/key_derivation.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

/// Maximum number of skipped message keys to store per session.
/// Prevents memory exhaustion from a malicious sender.
const _maxSkippedKeys = 1000;

/// Result of encrypting a message with the Signal Protocol.
class EncryptResult {
  /// AES-256-GCM ciphertext (includes auth tag).
  final Uint8List ciphertext;

  /// Double Ratchet header for this message.
  final RatchetHeader header;

  /// X3DH initial message (only for first message in session).
  final InitialMessage? initialMessage;

  /// Updated session state after encryption.
  final SessionState updatedSession;

  const EncryptResult({
    required this.ciphertext,
    required this.header,
    this.initialMessage,
    required this.updatedSession,
  });
}

/// Result of decrypting a message with the Signal Protocol.
class DecryptResult {
  /// Decrypted plaintext bytes.
  final Uint8List plaintext;

  /// Updated session state after decryption.
  final SessionState updatedSession;

  const DecryptResult({
    required this.plaintext,
    required this.updatedSession,
  });
}

/// Signal Protocol engine implementing X3DH key exchange and Double Ratchet.
///
/// This is the core cryptographic engine that provides:
/// - X3DH (Extended Triple Diffie-Hellman) for asynchronous key agreement
/// - Double Ratchet for forward-secret, future-secret message encryption
///
/// References:
/// - X3DH spec: https://signal.org/docs/specifications/x3dh/
/// - Double Ratchet spec: https://signal.org/docs/specifications/doubleratchet/
class SignalProtocolEngine {
  final CryptoProvider _crypto;
  final KeyDerivation _kdf;
  final AesGcmCipher _cipher;

  SignalProtocolEngine(this._crypto)
      : _kdf = KeyDerivation(_crypto),
        _cipher = AesGcmCipher(_crypto);

  // =========================================================================
  // X3DH Key Agreement (Initiator)
  // =========================================================================

  /// Perform X3DH key agreement as the initiator (Alice).
  ///
  /// Called when sending the first message to a new chat peer.
  /// Uses the recipient's published PreKeyBundle to compute a shared secret.
  ///
  /// Returns the initial session state and the InitialMessage to include
  /// with the first encrypted message.
  Future<({SessionState session, InitialMessage initialMessage})>
      performX3dhInitiator({
    required IdentityKeyPair localIdentity,
    required PreKeyBundle remoteBundle,
    required String remoteUserId,
  }) async {
    // 1. Verify the signed pre-key signature
    final spkValid = await _crypto.ed25519Verify(
      remoteBundle.signingKey,
      remoteBundle.signedPreKey.publicKey,
      remoteBundle.signedPreKey.signature,
    );
    if (!spkValid) {
      throw StateError(
        'Invalid signed pre-key signature for device ${remoteBundle.deviceId}',
      );
    }

    // 2. Generate ephemeral X25519 key pair
    final ephemeralKeyPair = await _crypto.generateX25519KeyPair();

    // 3. Compute the 4 (or 3) DH shared secrets
    //    DH1 = DH(IK_A_priv, SPK_B_pub)
    //    DH2 = DH(EK_A_priv, IK_B_pub)
    //    DH3 = DH(EK_A_priv, SPK_B_pub)
    //    DH4 = DH(EK_A_priv, OPK_B_pub)  [optional]

    final dh1 = await _crypto.x25519Dh(
      localIdentity.privateKey,
      remoteBundle.signedPreKey.publicKey,
    );

    final dh2 = await _crypto.x25519Dh(
      ephemeralKeyPair.privateKey,
      remoteBundle.identityKey,
    );

    final dh3 = await _crypto.x25519Dh(
      ephemeralKeyPair.privateKey,
      remoteBundle.signedPreKey.publicKey,
    );

    // 4. Combine DH outputs into master secret
    final dhOutputs = [dh1, dh2, dh3];
    int? consumedOpkId;

    if (remoteBundle.oneTimePreKeys.isNotEmpty) {
      final opk = remoteBundle.oneTimePreKeys.first;
      final dh4 = await _crypto.x25519Dh(
        ephemeralKeyPair.privateKey,
        opk.publicKey,
      );
      dhOutputs.add(dh4);
      consumedOpkId = opk.keyId;
    }

    final masterSecret = KeyDerivation.concatenate(dhOutputs);

    // 5. Derive root key and chain key via HKDF
    final (:rootKey, :chainKey) = await _kdf.deriveX3dhKeys(masterSecret);

    // 6. Generate our first ratchet DH key pair
    final ratchetKeyPair = await _crypto.generateX25519KeyPair();

    // 7. Perform initial DH ratchet step
    final dhOutput = await _crypto.x25519Dh(
      ratchetKeyPair.privateKey,
      remoteBundle.signedPreKey.publicKey,
    );

    final ratchetKeys = await _kdf.deriveRatchetKeys(rootKey, dhOutput);

    // 8. Build session state
    // Per Signal spec: Alice sets CKr = None initially
    final session = SessionState(
      remoteUserId: remoteUserId,
      remoteDeviceId: remoteBundle.deviceId,
      dhPrivateKey: ratchetKeyPair.privateKey,
      dhPublicKey: ratchetKeyPair.publicKey,
      remoteDhPublicKey: remoteBundle.signedPreKey.publicKey,
      rootKey: ratchetKeys.rootKey,
      sendingChainKey: ratchetKeys.chainKey,
      receivingChainKey: null,
      sendMessageNumber: 0,
      receiveMessageNumber: 0,
      previousSendingChainLength: 0,
      remoteIdentityKey: remoteBundle.identityKey,
      lastActive: DateTime.now(),
    );

    // 9. Build initial message
    final initialMessage = InitialMessage(
      identityKey: base64Encode(localIdentity.publicKey),
      ephemeralKey: base64Encode(ephemeralKeyPair.publicKey),
      oneTimePreKeyId: consumedOpkId,
      signedPreKeyId: remoteBundle.signedPreKey.keyId,
      registrationId: localIdentity.registrationId,
    );

    return (session: session, initialMessage: initialMessage);
  }

  // =========================================================================
  // X3DH Key Agreement (Responder)
  // =========================================================================

  /// Perform X3DH key agreement as the responder (Bob).
  ///
  /// Called when receiving the first message from a new peer.
  /// Uses the InitialMessage from the sender to compute the same shared secret.
  Future<SessionState> performX3dhResponder({
    required IdentityKeyPair localIdentity,
    required InitialMessage initialMsg,
    required SignedPreKey localSignedPreKey,
    required OneTimePreKey? consumedOpk,
  }) async {
    // 1. Compute the matching DH shared secrets
    //    DH1 = DH(SPK_B_priv, IK_A_pub)
    //    DH2 = DH(IK_B_priv, EK_A_pub)
    //    DH3 = DH(SPK_B_priv, EK_A_pub)
    //    DH4 = DH(OPK_B_priv, EK_A_pub)  [optional]

    final remoteIdentityKey = initialMsg.identityKeyBytes;
    final remoteEphemeralKey = initialMsg.ephemeralKeyBytes;

    final dh1 = await _crypto.x25519Dh(
      localSignedPreKey.privateKey!,
      remoteIdentityKey,
    );

    final dh2 = await _crypto.x25519Dh(
      localIdentity.privateKey,
      remoteEphemeralKey,
    );

    final dh3 = await _crypto.x25519Dh(
      localSignedPreKey.privateKey!,
      remoteEphemeralKey,
    );

    final dhOutputs = [dh1, dh2, dh3];

    if (consumedOpk != null) {
      final dh4 = await _crypto.x25519Dh(
        consumedOpk.privateKey!,
        remoteEphemeralKey,
      );
      dhOutputs.add(dh4);
    }

    final masterSecret = KeyDerivation.concatenate(dhOutputs);

    // 2. Derive root key and chain key
    final (:rootKey, chainKey: _) = await _kdf.deriveX3dhKeys(masterSecret);

    // 3. Create session state
    // Per Signal spec: Bob uses SPK as his initial DH key pair,
    // DHr = None, CKs = None, CKr = None, RK = SK from X3DH.
    // The DH ratchet step happens when Bob receives Alice's first message.
    return SessionState(
      remoteUserId: '', // Will be filled by caller
      remoteDeviceId: '', // Will be filled by caller
      dhPrivateKey: localSignedPreKey.privateKey!,
      dhPublicKey: localSignedPreKey.publicKey,
      remoteDhPublicKey: null, // Set on first received DH ratchet
      rootKey: rootKey,
      sendingChainKey: null, // Set after first DH ratchet
      receivingChainKey: null, // Set after first DH ratchet
      sendMessageNumber: 0,
      receiveMessageNumber: 0,
      previousSendingChainLength: 0,
      remoteIdentityKey: remoteIdentityKey,
      lastActive: DateTime.now(),
    );
  }

  // =========================================================================
  // Double Ratchet Encrypt
  // =========================================================================

  /// Encrypt a plaintext message using the Double Ratchet.
  ///
  /// Advances the sending chain key, derives a message key,
  /// encrypts the plaintext with AES-256-GCM, and returns the
  /// ciphertext + header.
  Future<EncryptResult> encryptMessage(
    SessionState session,
    Uint8List plaintext, {
    InitialMessage? initialMessage,
  }) async {
    if (session.sendingChainKey == null) {
      throw StateError('Session has no sending chain key');
    }

    // 1. Advance chain key to get message key
    final (:messageKey, :nextChainKey) = await _kdf.advanceChainKey(
      session.sendingChainKey!,
    );

    // 2. Derive AES key + IV from message key
    final (:aesKey, :iv) = await _kdf.deriveMessageEncryptionKeys(messageKey);

    // 3. Build header
    final header = RatchetHeader(
      dhPublicKey: base64Encode(session.dhPublicKey),
      messageNumber: session.sendMessageNumber,
      previousChainLength: session.previousSendingChainLength,
    );

    // 4. Encrypt with AES-256-GCM (header as AAD)
    final ciphertext = await _cipher.encrypt(
      key: aesKey,
      iv: iv,
      plaintext: plaintext,
      aad: header.toAad(),
    );

    // 5. Update session state
    final updatedSession = session.copyWith(
      sendingChainKey: nextChainKey,
      sendMessageNumber: session.sendMessageNumber + 1,
      lastActive: DateTime.now(),
    );

    return EncryptResult(
      ciphertext: ciphertext,
      header: header,
      initialMessage: initialMessage,
      updatedSession: updatedSession,
    );
  }

  // =========================================================================
  // Double Ratchet Decrypt
  // =========================================================================

  /// Decrypt a message using the Double Ratchet.
  ///
  /// Handles DH ratchet steps (when the remote party's DH key changes),
  /// skipped messages (out-of-order delivery), and chain key advancement.
  Future<DecryptResult> decryptMessage(
    SessionState session,
    Uint8List ciphertext,
    RatchetHeader header,
  ) async {
    // 1. Try to decrypt from skipped message keys
    final skippedKey =
        '${header.dhPublicKey}:${header.messageNumber}';
    if (session.skippedMessageKeys.containsKey(skippedKey)) {
      final messageKey = session.skippedMessageKeys[skippedKey]!;
      final (:aesKey, :iv) =
          await _kdf.deriveMessageEncryptionKeys(messageKey);

      final plaintext = await _cipher.decrypt(
        key: aesKey,
        iv: iv,
        ciphertext: ciphertext,
        aad: header.toAad(),
      );

      // Remove used skipped key
      final updatedSkipped =
          Map<String, Uint8List>.from(session.skippedMessageKeys)
            ..remove(skippedKey);

      return DecryptResult(
        plaintext: plaintext,
        updatedSession: session.copyWith(
          skippedMessageKeys: updatedSkipped,
          lastActive: DateTime.now(),
        ),
      );
    }

    var currentSession = session;

    // 2. Check if we need a DH ratchet step
    final remoteDhKey = header.dhPublicKeyBytes;
    if (currentSession.remoteDhPublicKey == null ||
        !_bytesEqual(remoteDhKey, currentSession.remoteDhPublicKey!)) {
      // Skip any missed messages in the current receiving chain
      currentSession = await _skipMessageKeys(
        currentSession,
        header.previousChainLength,
      );

      // Perform DH ratchet step (receiving)
      currentSession = await _dhRatchetStep(currentSession, remoteDhKey);
    }

    // 3. Skip any missed messages in the new receiving chain
    currentSession = await _skipMessageKeys(
      currentSession,
      header.messageNumber,
    );

    // 4. Advance receiving chain key
    final (:messageKey, :nextChainKey) = await _kdf.advanceChainKey(
      currentSession.receivingChainKey!,
    );

    // 5. Derive AES key + IV
    final (:aesKey, :iv) = await _kdf.deriveMessageEncryptionKeys(messageKey);

    // 6. Decrypt
    final plaintext = await _cipher.decrypt(
      key: aesKey,
      iv: iv,
      ciphertext: ciphertext,
      aad: header.toAad(),
    );

    // 7. Update session
    final updatedSession = currentSession.copyWith(
      receivingChainKey: nextChainKey,
      receiveMessageNumber: currentSession.receiveMessageNumber + 1,
      lastActive: DateTime.now(),
    );

    return DecryptResult(
      plaintext: plaintext,
      updatedSession: updatedSession,
    );
  }

  // =========================================================================
  // DH Ratchet Step
  // =========================================================================

  /// Perform a DH ratchet step when the remote party's DH key changes.
  ///
  /// This provides future secrecy: even if the current chain key is
  /// compromised, new DH exchanges restore security.
  Future<SessionState> _dhRatchetStep(
    SessionState session,
    Uint8List remoteDhPublicKey,
  ) async {
    // 1. Derive new receiving chain
    final dhOutput1 = await _crypto.x25519Dh(
      session.dhPrivateKey,
      remoteDhPublicKey,
    );
    final receiveKeys =
        await _kdf.deriveRatchetKeys(session.rootKey, dhOutput1);

    // 2. Generate new DH key pair for our side
    final newKeyPair = await _crypto.generateX25519KeyPair();

    // 3. Derive new sending chain
    final dhOutput2 = await _crypto.x25519Dh(
      newKeyPair.privateKey,
      remoteDhPublicKey,
    );
    final sendKeys =
        await _kdf.deriveRatchetKeys(receiveKeys.rootKey, dhOutput2);

    return session.copyWith(
      dhPrivateKey: newKeyPair.privateKey,
      dhPublicKey: newKeyPair.publicKey,
      remoteDhPublicKey: remoteDhPublicKey,
      rootKey: sendKeys.rootKey,
      sendingChainKey: sendKeys.chainKey,
      receivingChainKey: receiveKeys.chainKey,
      previousSendingChainLength: session.sendMessageNumber,
      sendMessageNumber: 0,
      receiveMessageNumber: 0,
    );
  }

  // =========================================================================
  // Skipped Message Keys
  // =========================================================================

  /// Store message keys for skipped messages (out-of-order delivery).
  ///
  /// When we receive a message with a higher sequence number than expected,
  /// we compute and store the intermediate message keys so they can be
  /// used if those messages arrive later.
  Future<SessionState> _skipMessageKeys(
    SessionState session,
    int untilMessageNumber,
  ) async {
    if (session.receivingChainKey == null) return session;

    if (untilMessageNumber - session.receiveMessageNumber > _maxSkippedKeys) {
      throw StateError(
        'Too many skipped messages: ${untilMessageNumber - session.receiveMessageNumber}',
      );
    }

    var chainKey = session.receivingChainKey!;
    final skippedKeys = Map<String, Uint8List>.from(session.skippedMessageKeys);
    var messageNumber = session.receiveMessageNumber;

    while (messageNumber < untilMessageNumber) {
      final (:messageKey, :nextChainKey) =
          await _kdf.advanceChainKey(chainKey);

      final remoteDhKey = session.remoteDhPublicKey != null
          ? base64Encode(session.remoteDhPublicKey!)
          : '';
      skippedKeys['$remoteDhKey:$messageNumber'] = messageKey;

      chainKey = nextChainKey;
      messageNumber++;
    }

    return session.copyWith(
      receivingChainKey: chainKey,
      receiveMessageNumber: messageNumber,
      skippedMessageKeys: skippedKeys,
    );
  }

  /// Compare two byte arrays for equality in constant time.
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
