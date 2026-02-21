import 'dart:convert';
import 'dart:typed_data';

import 'package:securityexperts_app/core/crypto/crypto_provider.dart';
import 'package:securityexperts_app/core/crypto/secure_random.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/crypto/session_repository.dart';

/// Web implementation of [ISessionRepository].
///
/// Uses an in-memory store with AES-256-GCM encryption for session state.
/// Session data is encrypted with a randomly generated wrapping key
/// and stored as JSON strings.
///
/// Unlike [NativeSessionRepository] which uses `flutter_secure_storage`,
/// this implementation avoids native platform dependencies and works
/// in any Dart environment including web browsers and tests.
///
/// Security notes:
/// - Session state persists in-memory only (cleared on page reload)
/// - For production web, consider persisting to IndexedDB with
///   non-extractable CryptoKey wrapping
/// - Tab suspension/crash: state is lost; sessions re-establish
///   from initial messages on next communication
class WebSessionRepository implements ISessionRepository {
  final CryptoProvider _crypto;

  /// In-memory encrypted store.
  final Map<String, _EncryptedEntry> _store = {};

  /// Session index tracking all stored session keys.
  final Set<String> _index = {};

  /// AES-256-GCM wrapping key for this session.
  late final Uint8List _wrappingKey;

  static const _sessionPrefix = 'e2ee_session_';

  WebSessionRepository({required CryptoProvider crypto}) : _crypto = crypto {
    _wrappingKey = SecureRandom.generateAesKey();
  }

  /// Composite key for a session.
  String _sessionKey(String userId, String deviceId) =>
      '$_sessionPrefix${userId}_$deviceId';

  // =========================================================================
  // Encrypted Storage Helpers
  // =========================================================================

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

  void _delete(String key) {
    _store.remove(key);
  }

  // =========================================================================
  // ISessionRepository Implementation
  // =========================================================================

  @override
  Future<void> saveSession(SessionState session) async {
    final key = _sessionKey(session.remoteUserId, session.remoteDeviceId);
    final data = jsonEncode(session.serialize());
    await _write(key, data);
    _index.add(key);
  }

  @override
  Future<SessionState?> getSession(
    String remoteUserId,
    String remoteDeviceId,
  ) async {
    final key = _sessionKey(remoteUserId, remoteDeviceId);
    final encoded = await _read(key);
    if (encoded == null) return null;

    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return SessionState.deserialize(json);
  }

  @override
  Future<List<SessionState>> getSessionsForUser(String remoteUserId) async {
    final sessions = <SessionState>[];
    final prefix = '$_sessionPrefix${remoteUserId}_';

    for (final key in _index) {
      if (key.startsWith(prefix)) {
        final encoded = await _read(key);
        if (encoded != null) {
          final json = jsonDecode(encoded) as Map<String, dynamic>;
          sessions.add(SessionState.deserialize(json));
        }
      }
    }

    return sessions;
  }

  @override
  Future<void> deleteSession(
    String remoteUserId,
    String remoteDeviceId,
  ) async {
    final key = _sessionKey(remoteUserId, remoteDeviceId);
    _delete(key);
    _index.remove(key);
  }

  @override
  Future<void> deleteSessionsForUser(String remoteUserId) async {
    final prefix = '$_sessionPrefix${remoteUserId}_';
    final keysToRemove = _index.where((k) => k.startsWith(prefix)).toList();

    for (final key in keysToRemove) {
      _delete(key);
      _index.remove(key);
    }
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
    _index.clear();
  }
}

/// An encrypted entry in the web session store.
class _EncryptedEntry {
  final Uint8List iv;
  final Uint8List ciphertext;

  const _EncryptedEntry({required this.iv, required this.ciphertext});
}
