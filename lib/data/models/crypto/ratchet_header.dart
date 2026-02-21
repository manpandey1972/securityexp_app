import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Double Ratchet message header sent alongside each encrypted message.
///
/// Contains the sender's current ratchet public key and message
/// counters needed for the recipient to derive the correct message key.
class RatchetHeader extends Equatable {
  /// Sender's current DH ratchet public key (32 bytes, Base64).
  final String dhPublicKey;

  /// Message number in the current sending chain.
  final int messageNumber;

  /// Number of messages in the previous sending chain.
  final int previousChainLength;

  const RatchetHeader({
    required this.dhPublicKey,
    required this.messageNumber,
    required this.previousChainLength,
  });

  factory RatchetHeader.fromJson(Map<String, dynamic> json) {
    return RatchetHeader(
      dhPublicKey: json['dh_public_key'] as String? ?? '',
      messageNumber: json['message_number'] as int? ?? 0,
      previousChainLength: json['previous_chain_length'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dh_public_key': dhPublicKey,
      'message_number': messageNumber,
      'previous_chain_length': previousChainLength,
    };
  }

  Uint8List get dhPublicKeyBytes => base64Decode(dhPublicKey);

  /// Serialize header to bytes for use as AAD in AES-GCM.
  Uint8List toAad() {
    final json = toJson();
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  @override
  List<Object?> get props => [dhPublicKey, messageNumber, previousChainLength];
}
