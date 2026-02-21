import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/crypto/signal_protocol_engine.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/prekey_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/session_repository.dart';

/// Orchestrates E2EE for chat messages.
///
/// Manages session lifecycle, encrypts outgoing messages,
/// and decrypts incoming messages using the Signal Protocol.
///
/// This is the primary interface used by the chat feature layer
/// for all encryption/decryption operations.
class EncryptionService {
  final SignalProtocolEngine _protocol;
  final IKeyStoreRepository _keyStore;
  final ISessionRepository _sessionRepo;
  final PreKeyRepository _preKeyRepo;

  /// In-memory LRU cache for hot sessions (avoids repeated storage reads).
  final Map<String, SessionState> _sessionCache = {};
  static const _maxCacheSize = 20;

  EncryptionService({
    required SignalProtocolEngine protocol,
    required IKeyStoreRepository keyStore,
    required ISessionRepository sessionRepo,
    required PreKeyRepository preKeyRepo,
  })  : _protocol = protocol,
        _keyStore = keyStore,
        _sessionRepo = sessionRepo,
        _preKeyRepo = preKeyRepo;

  // =========================================================================
  // Encrypt
  // =========================================================================

  /// Encrypt a message for a remote user.
  ///
  /// Establishes a session if one doesn't exist (X3DH), then encrypts
  /// the plaintext using the Double Ratchet.
  ///
  /// Returns an [EncryptedMessage] ready to be stored in Firestore.
  Future<EncryptedMessage> encryptMessage({
    required String remoteUserId,
    required String messageType,
    required DecryptedContent content,
    String? remoteDeviceId,
  }) async {
    final identity = await _keyStore.getIdentityKeyPair();
    if (identity == null) {
      throw StateError('No identity key pair found. Device not registered.');
    }

    // Get or create session
    var session = await _getSession(remoteUserId, remoteDeviceId);
    InitialMessage? initialMessage;

    if (session == null) {
      // No session exists — perform X3DH to create one
      final bundle = await _preKeyRepo.fetchAndConsumePreKeyBundle(
        userId: remoteUserId,
        deviceId: remoteDeviceId,
      );

      if (bundle == null) {
        throw StateError(
          'No PreKeyBundle available for user $remoteUserId. '
          'They may not have registered E2EE.',
        );
      }

      // Store remote identity key (TOFU)
      final keyChanged = await _keyStore.hasIdentityKeyChanged(
        remoteUserId,
        bundle.identityKey,
      );
      if (keyChanged) {
        // Identity key changed — this could be a new device or MITM
        // For now, we update the stored key and let the UI layer
        // handle the warning via IdentityKeyChangeDetector
        await _keyStore.storeRemoteIdentityKey(
          remoteUserId,
          bundle.identityKey,
        );
      } else {
        await _keyStore.storeRemoteIdentityKey(
          remoteUserId,
          bundle.identityKey,
        );
      }

      final result = await _protocol.performX3dhInitiator(
        localIdentity: identity,
        remoteBundle: bundle,
        remoteUserId: remoteUserId,
      );

      session = result.session.copyWith(
        remoteUserId: remoteUserId,
        remoteDeviceId: bundle.deviceId,
      );
      initialMessage = result.initialMessage;
    }

    // Encrypt the plaintext content
    final plaintext = content.toBytes();
    final encryptResult = await _protocol.encryptMessage(
      session,
      plaintext,
      initialMessage: initialMessage,
    );

    // Save updated session state
    await _saveSession(encryptResult.updatedSession);

    // Build EncryptedMessage
    return EncryptedMessage(
      id: '', // Set by Firestore
      senderId: '', // Set by caller
      type: messageType,
      ciphertext: base64Encode(encryptResult.ciphertext),
      header: encryptResult.header,
      initialMessage: encryptResult.initialMessage,
      timestamp: Timestamp.now(),
    );
  }

  // =========================================================================
  // Decrypt
  // =========================================================================

  /// Decrypt a received encrypted message.
  ///
  /// If the message contains an InitialMessage, performs X3DH as responder
  /// to establish the session first.
  ///
  /// Returns the [DecryptedContent].
  Future<DecryptedContent> decryptMessage({
    required EncryptedMessage message,
  }) async {
    final identity = await _keyStore.getIdentityKeyPair();
    if (identity == null) {
      throw StateError('No identity key pair found. Device not registered.');
    }

    var session = await _getSession(message.senderId, null);

    // Check if this is an initial message (new session)
    if (message.initialMessage != null && session == null) {
      session = await _initializeSessionAsResponder(
        identity: identity,
        initialMessage: message.initialMessage!,
        senderId: message.senderId,
      );
    }

    if (session == null) {
      throw StateError(
        'No session found for sender ${message.senderId}. '
        'Message may be from an unknown device.',
      );
    }

    // Decrypt with Double Ratchet
    final ciphertext = base64Decode(message.ciphertext);
    final result = await _protocol.decryptMessage(
      session,
      ciphertext,
      message.header,
    );

    // Save updated session state
    await _saveSession(result.updatedSession);

    // Parse decrypted content
    return DecryptedContent.fromBytes(result.plaintext);
  }

  // =========================================================================
  // Session Management
  // =========================================================================

  /// Check if an E2EE session exists with a remote user.
  Future<bool> hasSession(String remoteUserId) async {
    final session = await _getSession(remoteUserId, null);
    return session != null;
  }

  /// Get the identity key status for a remote user.
  Future<IdentityKeyStatus> checkIdentityKey(String remoteUserId) async {
    final storedKey = await _keyStore.getRemoteIdentityKey(remoteUserId);
    if (storedKey == null) return IdentityKeyStatus.unknown;

    final bundle = await _preKeyRepo.fetchPreKeyBundle(
      userId: remoteUserId,
    );
    if (bundle == null) return IdentityKeyStatus.unknown;

    final changed = await _keyStore.hasIdentityKeyChanged(
      remoteUserId,
      bundle.identityKey,
    );

    return changed ? IdentityKeyStatus.changed : IdentityKeyStatus.trusted;
  }

  /// Clear all sessions and keys (sign-out).
  Future<void> clearAll() async {
    _sessionCache.clear();
    await _sessionRepo.clearAll();
    await _keyStore.clearAll();
  }

  // =========================================================================
  // Private Helpers
  // =========================================================================

  /// Initialize session as responder using X3DH.
  Future<SessionState> _initializeSessionAsResponder({
    required IdentityKeyPair identity,
    required InitialMessage initialMessage,
    required String senderId,
  }) async {
    // Get our signed pre-key
    final spk = await _keyStore.getSignedPreKey(initialMessage.signedPreKeyId);
    if (spk == null) {
      throw StateError(
        'Signed pre-key ${initialMessage.signedPreKeyId} not found. '
        'It may have been rotated.',
      );
    }

    // Get consumed OPK (if any)
    OneTimePreKey? consumedOpk;
    if (initialMessage.oneTimePreKeyId != null) {
      consumedOpk = await _keyStore.getOneTimePreKey(
        initialMessage.oneTimePreKeyId!,
      );
      if (consumedOpk != null) {
        // Delete consumed OPK
        await _keyStore.deleteOneTimePreKey(initialMessage.oneTimePreKeyId!);
      }
    }

    // Perform X3DH as responder
    var session = await _protocol.performX3dhResponder(
      localIdentity: identity,
      initialMsg: initialMessage,
      localSignedPreKey: spk,
      consumedOpk: consumedOpk,
    );

    // Fill in remote user/device info
    session = session.copyWith(
      remoteUserId: senderId,
      remoteDeviceId: '', // Will be determined from sender
    );

    // Store remote identity key (TOFU)
    await _keyStore.storeRemoteIdentityKey(
      senderId,
      initialMessage.identityKeyBytes,
    );

    return session;
  }

  /// Get session from cache or storage.
  Future<SessionState?> _getSession(
    String remoteUserId,
    String? remoteDeviceId,
  ) async {
    // Check cache first
    final cacheKey = '$remoteUserId:${remoteDeviceId ?? ''}';
    if (_sessionCache.containsKey(cacheKey)) {
      return _sessionCache[cacheKey];
    }

    // Load from storage
    if (remoteDeviceId != null) {
      final session = await _sessionRepo.getSession(
        remoteUserId,
        remoteDeviceId,
      );
      if (session != null) {
        _cacheSession(cacheKey, session);
      }
      return session;
    }

    // No device ID — get any session for this user
    final sessions = await _sessionRepo.getSessionsForUser(remoteUserId);
    if (sessions.isEmpty) return null;

    // Use most recently active session
    sessions.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    final session = sessions.first;
    _cacheSession(cacheKey, session);
    return session;
  }

  /// Save session to storage and cache.
  Future<void> _saveSession(SessionState session) async {
    await _sessionRepo.saveSession(session);
    final cacheKey = '${session.remoteUserId}:${session.remoteDeviceId}';
    _cacheSession(cacheKey, session);
  }

  /// Add session to LRU cache, evicting oldest if full.
  void _cacheSession(String key, SessionState session) {
    if (_sessionCache.length >= _maxCacheSize) {
      _sessionCache.remove(_sessionCache.keys.first);
    }
    _sessionCache[key] = session;
  }
}

/// Status of a remote user's identity key.
enum IdentityKeyStatus {
  /// No identity key stored (first contact).
  unknown,

  /// Identity key matches stored key (TOFU verified).
  trusted,

  /// Identity key has changed — possible device change or MITM.
  changed,

  /// Identity key manually verified by user (QR/safety number).
  verified,
}


