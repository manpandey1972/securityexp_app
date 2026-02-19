import 'package:securityexperts_app/data/models/models.dart';

/// Status of an upload task
enum UploadStatus {
  /// Upload is in progress
  uploading,

  /// Upload completed successfully
  completed,

  /// Upload failed
  failed,

  /// Upload was cancelled by user
  cancelled,
}

/// Represents the state of a single upload task
class UploadState {
  /// Unique identifier for this upload
  final String id;

  /// The chat room this upload belongs to
  final String roomId;

  /// Original filename
  final String filename;

  /// Type of message (image, video, audio, file)
  final MessageType type;

  /// Current status of the upload
  final UploadStatus status;

  /// Upload progress from 0.0 to 1.0
  final double progress;

  /// Error message if upload failed
  final String? error;

  /// ID of message being replied to (if any)
  final String? replyToMessageId;

  /// The full reply message (if any)
  final Message? replyToMessage;

  /// When the upload was started
  final DateTime startedAt;

  const UploadState({
    required this.id,
    required this.roomId,
    required this.filename,
    required this.type,
    required this.status,
    required this.progress,
    this.error,
    this.replyToMessageId,
    this.replyToMessage,
    required this.startedAt,
  });

  /// Create a copy with updated fields
  UploadState copyWith({
    String? id,
    String? roomId,
    String? filename,
    MessageType? type,
    UploadStatus? status,
    double? progress,
    String? error,
    String? replyToMessageId,
    Message? replyToMessage,
    DateTime? startedAt,
  }) {
    return UploadState(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      filename: filename ?? this.filename,
      type: type ?? this.type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// Whether this upload is still active (not completed/failed/cancelled)
  bool get isActive => status == UploadStatus.uploading;

  /// Human-readable status text
  String get statusText {
    switch (status) {
      case UploadStatus.uploading:
        return 'Uploading ${(progress * 100).toInt()}%';
      case UploadStatus.completed:
        return 'Completed';
      case UploadStatus.failed:
        return 'Failed';
      case UploadStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  String toString() {
    return 'UploadState(id: $id, filename: $filename, status: $status, progress: ${(progress * 100).toInt()}%)';
  }
}
