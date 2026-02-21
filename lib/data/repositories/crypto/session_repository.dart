import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

/// Repository for persisting Double Ratchet session state.
///
/// Session state is stored encrypted in platform-native secure storage.
/// Each session is keyed by the remote peer's userId + deviceId combination.
abstract class ISessionRepository {
  /// Save a session state for a remote peer device.
  Future<void> saveSession(SessionState session);

  /// Retrieve session state for a specific remote peer device.
  Future<SessionState?> getSession(String remoteUserId, String remoteDeviceId);

  /// Get all sessions for a remote user (all their devices).
  Future<List<SessionState>> getSessionsForUser(String remoteUserId);

  /// Delete a session for a specific remote peer device.
  Future<void> deleteSession(String remoteUserId, String remoteDeviceId);

  /// Delete all sessions for a remote user.
  Future<void> deleteSessionsForUser(String remoteUserId);

  /// Delete all sessions (sign-out).
  Future<void> clearAll();
}

/// Native (iOS/Android) implementation of [ISessionRepository].
///
/// Uses [FlutterSecureStorage] for encrypted persistence.
/// Session state is serialized to JSON and stored with a composite key.
class NativeSessionRepository implements ISessionRepository {
  final FlutterSecureStorage _secureStorage;

  static const _sessionPrefix = 'e2ee_session_';
  static const _sessionIndexKey = 'e2ee_session_index';

  NativeSessionRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
            );

  /// Composite key for a session: "e2ee_session_{userId}_{deviceId}"
  String _sessionKey(String userId, String deviceId) =>
      '$_sessionPrefix${userId}_$deviceId';

  @override
  Future<void> saveSession(SessionState session) async {
    final key = _sessionKey(session.remoteUserId, session.remoteDeviceId);
    final data = jsonEncode(session.serialize());
    await _secureStorage.write(key: key, value: data);

    // Update session index
    await _addToIndex(key);
  }

  @override
  Future<SessionState?> getSession(
    String remoteUserId,
    String remoteDeviceId,
  ) async {
    final key = _sessionKey(remoteUserId, remoteDeviceId);
    final encoded = await _secureStorage.read(key: key);
    if (encoded == null) return null;

    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return SessionState.deserialize(json);
  }

  @override
  Future<List<SessionState>> getSessionsForUser(String remoteUserId) async {
    final index = await _getIndex();
    final sessions = <SessionState>[];

    final prefix = '$_sessionPrefix${remoteUserId}_';
    for (final key in index) {
      if (key.startsWith(prefix)) {
        final encoded = await _secureStorage.read(key: key);
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
    await _secureStorage.delete(key: key);
    await _removeFromIndex(key);
  }

  @override
  Future<void> deleteSessionsForUser(String remoteUserId) async {
    final index = await _getIndex();
    final prefix = '$_sessionPrefix${remoteUserId}_';

    for (final key in index.toList()) {
      if (key.startsWith(prefix)) {
        await _secureStorage.delete(key: key);
        index.remove(key);
      }
    }

    await _saveIndex(index);
  }

  @override
  Future<void> clearAll() async {
    final index = await _getIndex();
    for (final key in index) {
      await _secureStorage.delete(key: key);
    }
    await _secureStorage.delete(key: _sessionIndexKey);
  }

  // =========================================================================
  // Session Index Management
  // =========================================================================

  Future<Set<String>> _getIndex() async {
    final encoded = await _secureStorage.read(key: _sessionIndexKey);
    if (encoded == null) return {};
    final list = jsonDecode(encoded) as List<dynamic>;
    return list.map((e) => e as String).toSet();
  }

  Future<void> _saveIndex(Set<String> index) async {
    await _secureStorage.write(
      key: _sessionIndexKey,
      value: jsonEncode(index.toList()),
    );
  }

  Future<void> _addToIndex(String key) async {
    final index = await _getIndex();
    index.add(key);
    await _saveIndex(index);
  }

  Future<void> _removeFromIndex(String key) async {
    final index = await _getIndex();
    index.remove(key);
    await _saveIndex(index);
  }
}
