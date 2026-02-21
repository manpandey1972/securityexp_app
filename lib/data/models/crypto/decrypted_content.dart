import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// The plaintext content of a decrypted message.
///
/// After Double Ratchet decryption, the plaintext is deserialized
/// into this structure. For media messages, this contains the
/// encrypted media key and URL needed to decrypt the media file.
class DecryptedContent extends Equatable {
  /// Text content of the message.
  final String? text;

  /// Encrypted media URL (path in Firebase Storage).
  final String? mediaUrl;

  /// Media encryption key + IV (44 bytes: 32-byte key + 12-byte IV, Base64).
  final String? mediaKey;

  /// SHA-256 hash of the plaintext media file for integrity verification.
  final String? mediaHash;

  /// MIME type of the media (e.g., "image/jpeg").
  final String? mediaType;

  /// Size of the original plaintext media file in bytes.
  final int? mediaSize;

  /// Encrypted thumbnail URL.
  final String? thumbnailUrl;

  /// Thumbnail encryption key + IV (44 bytes, Base64).
  final String? thumbnailKey;

  /// Original filename (for documents).
  final String? fileName;

  /// Reply-to message ID.
  final String? replyToMessageId;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const DecryptedContent({
    this.text,
    this.mediaUrl,
    this.mediaKey,
    this.mediaHash,
    this.mediaType,
    this.mediaSize,
    this.thumbnailUrl,
    this.thumbnailKey,
    this.fileName,
    this.replyToMessageId,
    this.metadata,
  });

  /// Serialize to bytes for encryption by the Double Ratchet.
  Uint8List toBytes() {
    final json = toJson();
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Deserialize from decrypted bytes.
  factory DecryptedContent.fromBytes(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return DecryptedContent.fromJson(json);
  }

  factory DecryptedContent.fromJson(Map<String, dynamic> json) {
    return DecryptedContent(
      text: json['text'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaKey: json['media_key'] as String?,
      mediaHash: json['media_hash'] as String?,
      mediaType: json['media_type'] as String?,
      mediaSize: json['media_size'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      thumbnailKey: json['thumbnail_key'] as String?,
      fileName: json['file_name'] as String?,
      replyToMessageId: json['reply_to_message_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (text != null) 'text': text,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaKey != null) 'media_key': mediaKey,
      if (mediaHash != null) 'media_hash': mediaHash,
      if (mediaType != null) 'media_type': mediaType,
      if (mediaSize != null) 'media_size': mediaSize,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (thumbnailKey != null) 'thumbnail_key': thumbnailKey,
      if (fileName != null) 'file_name': fileName,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Whether this content contains media (image, video, audio, document).
  bool get hasMedia => mediaUrl != null && mediaKey != null;

  @override
  List<Object?> get props => [
        text,
        mediaUrl,
        mediaKey,
        mediaHash,
        mediaType,
        mediaSize,
        thumbnailUrl,
        thumbnailKey,
        fileName,
        replyToMessageId,
        metadata,
      ];
}
