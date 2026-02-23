import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/models/crypto/room_key_info.dart';

/// Manages room key retrieval from Cloud Functions.
///
/// Caches plaintext room keys in memory (never persisted to disk).
/// Each room's AES-256 key is fetched once per app session from the
/// `sealRoomKey` / `getRoomKey` Cloud Functions, then cached in a
/// Dart [Map] for the lifetime of the service instance.
class RoomKeyService {
  static const String _tag = 'RoomKeyService';

  final FirebaseFunctions _functions;
  final AppLogger _log;

  /// In-memory cache: roomId → RoomKeyInfo.
  final Map<String, RoomKeyInfo> _cache = {};

  RoomKeyService({
    required FirebaseFunctions functions,
    required AppLogger logger,
  })  : _functions = functions,
        _log = logger;

  /// Get the room key, from cache or Cloud Function.
  ///
  /// First checks the in-memory cache. On miss, calls the
  /// `getRoomKey` Cloud Function, which verifies the caller is
  /// a room participant and returns the KMS-decrypted key.
  Future<RoomKeyInfo> getRoomKey(String roomId) async {
    // 1. Check memory cache
    final cached = _cache[roomId];
    if (cached != null) return cached;

    // 2. Call Cloud Function
    _log.debug('Fetching room key for $roomId', tag: _tag);

    final result = await _functions
        .httpsCallable('api')
        .call<Map<String, dynamic>>(
          {'action': 'getRoomKey', 'payload': {'roomId': roomId}},
        );

    final data = result.data;
    final keyBytes = base64Decode(data['roomKey'] as String);

    final info = RoomKeyInfo(
      roomId: roomId,
      key: Uint8List.fromList(keyBytes),
      retrievedAt: DateTime.now(),
    );

    // 3. Cache in memory
    _cache[roomId] = info;
    _log.debug('Room key cached for $roomId', tag: _tag);
    return info;
  }

  /// Seal a new room key (called after room creation).
  ///
  /// Calls the `sealRoomKey` Cloud Function which generates a
  /// random AES-256 key, KMS-encrypts it, stores the ciphertext
  /// on the room document, and returns the plaintext key.
  Future<RoomKeyInfo> sealRoomKey(String roomId) async {
    _log.debug('Sealing room key for $roomId', tag: _tag);

    final result = await _functions
        .httpsCallable('api')
        .call<Map<String, dynamic>>(
          {'action': 'sealRoomKey', 'payload': {'roomId': roomId}},
        );

    final data = result.data;
    final keyBytes = base64Decode(data['roomKey'] as String);

    final info = RoomKeyInfo(
      roomId: roomId,
      key: Uint8List.fromList(keyBytes),
      retrievedAt: DateTime.now(),
    );

    _cache[roomId] = info;
    _log.info('Room key sealed and cached for $roomId', tag: _tag);
    return info;
  }

  /// Clear all cached keys (call on logout).
  void clearCache() {
    for (final info in _cache.values) {
      info.dispose();
    }
    _cache.clear();
    _log.debug('Room key cache cleared', tag: _tag);
  }

  /// Clear a specific room's key from cache.
  void evict(String roomId) {
    _cache[roomId]?.dispose();
    _cache.remove(roomId);
  }
}
