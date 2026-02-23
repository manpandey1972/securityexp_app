import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// An encrypted message stored in Firestore (v2 — per-room AES-256-GCM).
///
/// The ciphertext is produced by AES-256-GCM using the room's
/// symmetric key. Only room participants (authenticated via Cloud
/// Functions) can obtain the key to decrypt.
class EncryptedMessage extends Equatable {
  /// Firestore document ID.
  final String id;

  /// Sender's user ID.
  final String senderId;

  /// Message type indicator (text, image, video, audio, doc).
  /// This is NOT encrypted — used for push notification hints only.
  final String type;

  /// AES-256-GCM ciphertext (Base64-encoded).
  final String ciphertext;

  /// 12-byte GCM initialization vector (Base64-encoded).
  final String iv;

  /// Server timestamp.
  final Timestamp timestamp;

  /// Encryption protocol version for forward compatibility.
  /// v1 = Signal Protocol (deprecated), v2 = per-room AES-256-GCM.
  final int encryptionVersion;

  const EncryptedMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.ciphertext,
    required this.iv,
    required this.timestamp,
    this.encryptionVersion = 2,
  });

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      ciphertext: json['ciphertext'] as String? ?? '',
      iv: json['iv'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?) ?? Timestamp.now(),
      encryptionVersion: json['encryption_version'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'type': type,
      'ciphertext': ciphertext,
      'iv': iv,
      'timestamp': FieldValue.serverTimestamp(),
      'encryption_version': encryptionVersion,
    };
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        type,
        ciphertext,
        iv,
        timestamp,
        encryptionVersion,
      ];
}
