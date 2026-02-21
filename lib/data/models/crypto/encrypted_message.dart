import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:securityexperts_app/data/models/crypto/ratchet_header.dart';

/// An encrypted message stored in Firestore.
///
/// The ciphertext is produced by the Double Ratchet algorithm.
/// Only the sender and recipient can decrypt the message content.
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

  /// Double Ratchet message header.
  final RatchetHeader header;

  /// Present on first message in a session (X3DH initial message).
  final InitialMessage? initialMessage;

  /// Server timestamp.
  final Timestamp timestamp;

  /// Encryption protocol version for forward compatibility.
  final int encryptionVersion;

  const EncryptedMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.ciphertext,
    required this.header,
    this.initialMessage,
    required this.timestamp,
    this.encryptionVersion = 1,
  });

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      ciphertext: json['ciphertext'] as String? ?? '',
      header: RatchetHeader.fromJson(
        json['header'] as Map<String, dynamic>? ?? {},
      ),
      initialMessage: json['initial_message'] != null
          ? InitialMessage.fromJson(
              json['initial_message'] as Map<String, dynamic>,
            )
          : null,
      timestamp: (json['timestamp'] as Timestamp?) ?? Timestamp.now(),
      encryptionVersion: json['encryption_version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'type': type,
      'ciphertext': ciphertext,
      'header': header.toJson(),
      if (initialMessage != null) 'initial_message': initialMessage!.toJson(),
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
        header,
        initialMessage,
        timestamp,
        encryptionVersion,
      ];
}

/// X3DH initial message included with the first message in a session.
///
/// Contains the sender's ephemeral key and identity key so the
/// recipient can compute the same shared secret.
class InitialMessage extends Equatable {
  /// Sender's X25519 identity public key (32 bytes, Base64).
  final String identityKey;

  /// Ephemeral X25519 public key used for this X3DH exchange (32 bytes, Base64).
  final String ephemeralKey;

  /// ID of the consumed one-time pre-key (if available).
  final int? oneTimePreKeyId;

  /// ID of the signed pre-key used.
  final int signedPreKeyId;

  /// Sender's registration ID.
  final int registrationId;

  const InitialMessage({
    required this.identityKey,
    required this.ephemeralKey,
    this.oneTimePreKeyId,
    required this.signedPreKeyId,
    required this.registrationId,
  });

  factory InitialMessage.fromJson(Map<String, dynamic> json) {
    return InitialMessage(
      identityKey: json['identity_key'] as String? ?? '',
      ephemeralKey: json['ephemeral_key'] as String? ?? '',
      oneTimePreKeyId: json['one_time_pre_key_id'] as int?,
      signedPreKeyId: json['signed_pre_key_id'] as int? ?? 0,
      registrationId: json['registration_id'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity_key': identityKey,
      'ephemeral_key': ephemeralKey,
      if (oneTimePreKeyId != null) 'one_time_pre_key_id': oneTimePreKeyId,
      'signed_pre_key_id': signedPreKeyId,
      'registration_id': registrationId,
    };
  }

  Uint8List get identityKeyBytes => base64Decode(identityKey);
  Uint8List get ephemeralKeyBytes => base64Decode(ephemeralKey);

  @override
  List<Object?> get props => [
        identityKey,
        ephemeralKey,
        oneTimePreKeyId,
        signedPreKeyId,
        registrationId,
      ];
}
