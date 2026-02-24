import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:securityexperts_app/data/models/message_type.dart';

export 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Message defines the structure for a chat message.
class Message extends Equatable {
  final String id;
  final String senderId;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final String? replyToMessageId;
  final Message? replyToMessage;
  final Timestamp timestamp;
  final Map<String, dynamic>? metadata;

  /// Whether this message was end-to-end encrypted.
  /// Used by the UI to show encryption status indicators.
  final bool isEncrypted;

  /// Whether decryption failed for this message.
  /// When true, [text] contains a fallback error string.
  final bool decryptionFailed;

  /// Base64-encoded AES key+IV for decrypting the encrypted media file.
  /// Only set for messages with encrypted media attachments.
  final String? mediaKey;

  /// SHA-256 hash of the original plaintext media, used for integrity check.
  final String? mediaHash;

  /// MIME type of the original media (e.g. "image/jpeg").
  final String? mediaType;

  /// Size in bytes of the original plaintext media.
  final int? mediaSize;

  /// Original filename of the media attachment.
  final String? fileName;

  const Message({
    required this.id,
    required this.senderId,
    this.type = MessageType.text,
    this.text = '',
    this.mediaUrl,
    this.replyToMessageId,
    this.replyToMessage,
    required this.timestamp,
    this.metadata,
    this.isEncrypted = false,
    this.decryptionFailed = false,
    this.mediaKey,
    this.mediaHash,
    this.mediaType,
    this.mediaSize,
    this.fileName,
  });

  // Convenience getters for common conversions
  DateTime get dateTime => timestamp.toDate();
  int get millisecondsSinceEpoch => timestamp.millisecondsSinceEpoch;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      type: MessageTypeExtension.fromJson(json['type'] as String? ?? 'text'),
      text: json['text'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToMessage: json['replyToMessage'] != null
          ? Message.fromJson(json['replyToMessage'] as Map<String, dynamic>)
          : null,
      timestamp: (json['timestamp'] as Timestamp?) ?? Timestamp.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'type': type.toJson(),
      'text': text,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToMessage != null) 'replyToMessage': replyToMessage!.toJson(),
      'timestamp': timestamp,
      if (metadata != null) 'metadata': metadata,
    };
  }

  Message copyWith({
    String? id,
    String? senderId,
    MessageType? type,
    String? text,
    String? mediaUrl,
    String? replyToMessageId,
    Message? replyToMessage,
    Timestamp? timestamp,
    Map<String, dynamic>? metadata,
    bool? isEncrypted,
    bool? decryptionFailed,
    String? mediaKey,
    String? mediaHash,
    String? mediaType,
    int? mediaSize,
    String? fileName,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      decryptionFailed: decryptionFailed ?? this.decryptionFailed,
      mediaKey: mediaKey ?? this.mediaKey,
      mediaHash: mediaHash ?? this.mediaHash,
      mediaType: mediaType ?? this.mediaType,
      mediaSize: mediaSize ?? this.mediaSize,
      fileName: fileName ?? this.fileName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    type,
    text,
    mediaUrl,
    replyToMessageId,
    replyToMessage,
    timestamp,
    metadata,
    isEncrypted,
    decryptionFailed,
    mediaKey,
    mediaHash,
    mediaType,
    mediaSize,
    fileName,
  ];
}
