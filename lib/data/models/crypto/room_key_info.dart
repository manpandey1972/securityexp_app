import 'dart:typed_data';

/// Cached room key for in-memory use.
///
/// Holds the plaintext AES-256 room key retrieved from the Cloud Function.
/// Never persisted to disk — lives only in the Dart heap.
class RoomKeyInfo {
  /// The room this key belongs to.
  final String roomId;

  /// 32-byte AES-256 key (plaintext, in-memory only).
  final Uint8List key;

  /// When this key was retrieved from the Cloud Function.
  final DateTime retrievedAt;

  RoomKeyInfo({
    required this.roomId,
    required this.key,
    required this.retrievedAt,
  });

  /// Securely zero-out key material.
  void dispose() {
    for (var i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }

  @override
  String toString() => 'RoomKeyInfo(roomId: $roomId, retrievedAt: $retrievedAt)';
}
