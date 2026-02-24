import 'dart:async';
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
///
/// Concurrent requests for the same room are coalesced into a single
/// Cloud Function call using [Completer]-based deduplication.
class RoomKeyService {
  static const String _tag = 'RoomKeyService';

  final FirebaseFunctions _functions;
  final AppLogger _log;

  /// In-memory cache: roomId → RoomKeyInfo.
  final Map<String, RoomKeyInfo> _cache = {};

  /// In-flight requests: coalesces concurrent calls for the same room.
  final Map<String, Future<RoomKeyInfo>> _pending = {};

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
  ///
  /// If the room has no key yet (pre-existing room), automatically
  /// seals one via `sealRoomKey`. Concurrent calls for the same room
  /// are coalesced into a single CF call.
  Future<RoomKeyInfo> getRoomKey(String roomId) async {
    // 1. Check memory cache
    final cached = _cache[roomId];
    if (cached != null) return cached;

    // 2. Coalesce concurrent requests for the same room
    if (_pending.containsKey(roomId)) {
      _log.debug('Coalescing concurrent key request for $roomId', tag: _tag);
      return _pending[roomId]!;
    }

    // 3. Start the fetch (only one in-flight per room)
    final future = _fetchOrSealRoomKey(roomId);
    _pending[roomId] = future;

    try {
      return await future;
    } finally {
      _pending.remove(roomId);
    }
  }

  /// Fetch the room key from CF, auto-sealing if it doesn't exist yet.
  Future<RoomKeyInfo> _fetchOrSealRoomKey(String roomId) async {
    _log.debug('Fetching room key for $roomId', tag: _tag);

    try {
      // Try getRoomKey first
      final result = await _functions
          .httpsCallable('api')
          .call<Map<String, dynamic>>(
            {'action': 'getRoomKey', 'payload': {'roomId': roomId}},
          );

      return _cacheResult(roomId, result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        // Room has no key yet (pre-existing room) — seal one now
        _log.info(
          'No room key for $roomId — auto-sealing',
          tag: _tag,
        );
        return sealRoomKey(roomId);
      }
      rethrow;
    }
  }

  /// Seal a new room key (called after room creation or on first access).
  ///
  /// Calls the `sealRoomKey` Cloud Function which generates a
  /// random AES-256 key, KMS-encrypts it, stores the ciphertext
  /// on the room document, and returns the plaintext key.
  ///
  /// Idempotent on the server side — if a key already exists,
  /// the CF returns the existing decrypted key.
  Future<RoomKeyInfo> sealRoomKey(String roomId) async {
    _log.debug('Sealing room key for $roomId', tag: _tag);

    final result = await _functions
        .httpsCallable('api')
        .call<Map<String, dynamic>>(
          {'action': 'sealRoomKey', 'payload': {'roomId': roomId}},
        );

    final info = _cacheResult(roomId, result.data);
    _log.info('Room key sealed and cached for $roomId', tag: _tag);
    return info;
  }

  /// Parse CF response and cache the room key.
  RoomKeyInfo _cacheResult(String roomId, Map<String, dynamic> data) {
    final keyBytes = base64Decode(data['roomKey'] as String);

    final info = RoomKeyInfo(
      roomId: roomId,
      key: Uint8List.fromList(keyBytes),
      retrievedAt: DateTime.now(),
    );

    _cache[roomId] = info;
    _log.debug('Room key cached for $roomId', tag: _tag);
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
