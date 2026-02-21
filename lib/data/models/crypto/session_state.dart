import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Persistent state for a Double Ratchet session with a specific peer device.
///
/// This state is serialized and stored encrypted in platform-native
/// secure storage. It contains the chain keys and DH ratchet keys
/// needed to encrypt/decrypt messages.
class SessionState extends Equatable {
  /// Remote peer's user ID.
  final String remoteUserId;

  /// Remote peer's device ID.
  final String remoteDeviceId;

  /// Our current DH ratchet key pair (private + public).
  final Uint8List dhPrivateKey;
  final Uint8List dhPublicKey;

  /// Remote party's current DH ratchet public key.
  final Uint8List? remoteDhPublicKey;

  /// Root key (32 bytes) — used to derive new chain keys on DH ratchet step.
  final Uint8List rootKey;

  /// Sending chain key (32 bytes) — advanced via HMAC for each sent message.
  final Uint8List? sendingChainKey;

  /// Receiving chain key (32 bytes) — advanced via HMAC for each received message.
  final Uint8List? receivingChainKey;

  /// Number of messages sent in current sending chain.
  final int sendMessageNumber;

  /// Number of messages received in current receiving chain.
  final int receiveMessageNumber;

  /// Number of messages in the previous sending chain (for header).
  final int previousSendingChainLength;

  /// Skipped message keys for out-of-order message decryption.
  /// Map of "dhPublicKey:messageNumber" → message key bytes.
  final Map<String, Uint8List> skippedMessageKeys;

  /// Remote identity key for verification.
  final Uint8List remoteIdentityKey;

  /// Timestamp of last activity.
  final DateTime lastActive;

  const SessionState({
    required this.remoteUserId,
    required this.remoteDeviceId,
    required this.dhPrivateKey,
    required this.dhPublicKey,
    this.remoteDhPublicKey,
    required this.rootKey,
    this.sendingChainKey,
    this.receivingChainKey,
    this.sendMessageNumber = 0,
    this.receiveMessageNumber = 0,
    this.previousSendingChainLength = 0,
    this.skippedMessageKeys = const {},
    required this.remoteIdentityKey,
    required this.lastActive,
  });

  /// Serialize session state to a JSON-encodable map for storage.
  Map<String, dynamic> serialize() {
    return {
      'remote_user_id': remoteUserId,
      'remote_device_id': remoteDeviceId,
      'dh_private_key': base64Encode(dhPrivateKey),
      'dh_public_key': base64Encode(dhPublicKey),
      if (remoteDhPublicKey != null)
        'remote_dh_public_key': base64Encode(remoteDhPublicKey!),
      'root_key': base64Encode(rootKey),
      if (sendingChainKey != null)
        'sending_chain_key': base64Encode(sendingChainKey!),
      if (receivingChainKey != null)
        'receiving_chain_key': base64Encode(receivingChainKey!),
      'send_message_number': sendMessageNumber,
      'receive_message_number': receiveMessageNumber,
      'previous_sending_chain_length': previousSendingChainLength,
      'skipped_message_keys': skippedMessageKeys.map(
        (k, v) => MapEntry(k, base64Encode(v)),
      ),
      'remote_identity_key': base64Encode(remoteIdentityKey),
      'last_active': lastActive.toIso8601String(),
    };
  }

  /// Deserialize session state from stored JSON.
  factory SessionState.deserialize(Map<String, dynamic> json) {
    final skippedKeys = <String, Uint8List>{};
    if (json['skipped_message_keys'] != null) {
      final map = json['skipped_message_keys'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        skippedKeys[entry.key] = base64Decode(entry.value as String);
      }
    }

    return SessionState(
      remoteUserId: json['remote_user_id'] as String,
      remoteDeviceId: json['remote_device_id'] as String,
      dhPrivateKey: base64Decode(json['dh_private_key'] as String),
      dhPublicKey: base64Decode(json['dh_public_key'] as String),
      remoteDhPublicKey: json['remote_dh_public_key'] != null
          ? base64Decode(json['remote_dh_public_key'] as String)
          : null,
      rootKey: base64Decode(json['root_key'] as String),
      sendingChainKey: json['sending_chain_key'] != null
          ? base64Decode(json['sending_chain_key'] as String)
          : null,
      receivingChainKey: json['receiving_chain_key'] != null
          ? base64Decode(json['receiving_chain_key'] as String)
          : null,
      sendMessageNumber: json['send_message_number'] as int? ?? 0,
      receiveMessageNumber: json['receive_message_number'] as int? ?? 0,
      previousSendingChainLength:
          json['previous_sending_chain_length'] as int? ?? 0,
      skippedMessageKeys: skippedKeys,
      remoteIdentityKey: base64Decode(json['remote_identity_key'] as String),
      lastActive: DateTime.parse(json['last_active'] as String),
    );
  }

  SessionState copyWith({
    String? remoteUserId,
    String? remoteDeviceId,
    Uint8List? dhPrivateKey,
    Uint8List? dhPublicKey,
    Uint8List? remoteDhPublicKey,
    Uint8List? rootKey,
    Uint8List? sendingChainKey,
    Uint8List? receivingChainKey,
    int? sendMessageNumber,
    int? receiveMessageNumber,
    int? previousSendingChainLength,
    Map<String, Uint8List>? skippedMessageKeys,
    Uint8List? remoteIdentityKey,
    DateTime? lastActive,
  }) {
    return SessionState(
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      dhPrivateKey: dhPrivateKey ?? this.dhPrivateKey,
      dhPublicKey: dhPublicKey ?? this.dhPublicKey,
      remoteDhPublicKey: remoteDhPublicKey ?? this.remoteDhPublicKey,
      rootKey: rootKey ?? this.rootKey,
      sendingChainKey: sendingChainKey ?? this.sendingChainKey,
      receivingChainKey: receivingChainKey ?? this.receivingChainKey,
      sendMessageNumber: sendMessageNumber ?? this.sendMessageNumber,
      receiveMessageNumber: receiveMessageNumber ?? this.receiveMessageNumber,
      previousSendingChainLength:
          previousSendingChainLength ?? this.previousSendingChainLength,
      skippedMessageKeys: skippedMessageKeys ?? this.skippedMessageKeys,
      remoteIdentityKey: remoteIdentityKey ?? this.remoteIdentityKey,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  @override
  List<Object?> get props => [
        remoteUserId,
        remoteDeviceId,
        dhPrivateKey,
        dhPublicKey,
        remoteDhPublicKey,
        rootKey,
        sendingChainKey,
        receivingChainKey,
        sendMessageNumber,
        receiveMessageNumber,
        previousSendingChainLength,
        skippedMessageKeys,
        remoteIdentityKey,
        lastActive,
      ];
}
