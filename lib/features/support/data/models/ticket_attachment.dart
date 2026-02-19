import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an attachment on a support ticket or message.
///
/// Attachments can be images, screenshots, or documents that
/// help illustrate the user's issue.
class TicketAttachment {
  /// Unique identifier for the attachment
  final String id;

  /// Firebase Storage URL for the file
  final String url;

  /// Original filename
  final String fileName;

  /// File size in bytes
  final int fileSize;

  /// MIME type of the file (e.g., "image/png")
  final String mimeType;

  /// When the attachment was uploaded
  final DateTime uploadedAt;

  const TicketAttachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedAt,
  });

  /// Check if the attachment is an image
  bool get isImage =>
      mimeType.startsWith('image/') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.gif') ||
      fileName.toLowerCase().endsWith('.webp');

  /// Check if the attachment is a PDF
  bool get isPdf =>
      mimeType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  /// Get human-readable file size
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Create from a Firestore document
  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'attachment',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      uploadedAt: _parseTimestamp(json['uploadedAt']),
    );
  }

  /// Convert to a Firestore-compatible map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  /// Create a copy with some fields replaced
  TicketAttachment copyWith({
    String? id,
    String? url,
    String? fileName,
    int? fileSize,
    String? mimeType,
    DateTime? uploadedAt,
  }) {
    return TicketAttachment(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'TicketAttachment(id: $id, fileName: $fileName, '
        'fileSize: $fileSizeFormatted, mimeType: $mimeType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TicketAttachment &&
        other.id == id &&
        other.url == url &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.mimeType == mimeType &&
        other.uploadedAt == uploadedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, url, fileName, fileSize, mimeType, uploadedAt);
  }
}
