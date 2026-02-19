import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

typedef UploadProgressCallback = void Function(String tempId, double progress);
typedef UploadCompleteCallback = void Function(String tempId);
typedef UploadErrorCallback = void Function(String tempId, Object error);

class MediaUploadService {
  final ChatMessageRepository _messageRepository;
  final AnalyticsService _analytics = sl<AnalyticsService>();

  MediaUploadService({ChatMessageRepository? messageRepository})
    : _messageRepository = messageRepository ?? sl<ChatMessageRepository>();

  /// Upload and send media message with progress tracking
  /// Callbacks are invoked for progress, completion, and error states
  Future<void> uploadAndSendMedia({
    required String? filePath,
    required dynamic bytes,
    required String filename,
    required String roomId,
    required String tempId,
    required UploadProgressCallback onProgress,
    required UploadCompleteCallback onComplete,
    required UploadErrorCallback onError,
    Message? replyToMessage,
  }) async {
    final trace = _analytics.newTrace('media_upload');
    final fileType = _getMediaType(filename);
    trace.putAttribute('media_type', fileType);
    await trace.start();

    await ErrorHandler.handle<void>(
      operation: () async {
        try {
        if (roomId.isEmpty) {
          SnackbarService.show('No room available to send attachments');
          return;
        }

        if (bytes == null && (filePath == null || filePath.isEmpty)) {
          SnackbarService.show('File data is empty');
          return;
        }

        // Convert HEIC/HEIF to JPEG if needed
        final convertedResult = await _convertHeicIfNeeded(
          filePath,
          bytes,
          filename,
        );
        bytes = convertedResult['bytes'];
        filename = convertedResult['filename'];

        // Calculate file size
        int? fileSize;
        if (bytes != null) {
          fileSize = (bytes as dynamic).length as int?;
        } else if (filePath != null && filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
            fileSize = await file.length();
          }
        }

        // Upload to Firebase Storage
        final downloadUrl = await _uploadToStorage(
          filePath: filePath,
          bytes: bytes,
          filename: filename,
          roomId: roomId,
          tempId: tempId,
          onProgress: onProgress,
          onError: onError,
        );

        // Create and send chat message
        await _sendChatMessage(
          downloadUrl: downloadUrl,
          filename: filename,
          roomId: roomId,
          fileSize: fileSize,
          replyToMessage: replyToMessage,
        );

        onComplete(tempId);
        } finally {
          await trace.stop();
        }
      },
      onError: (error) {
        trace.putAttribute('error', error.runtimeType.toString());
        trace.stop();
        onError(tempId, error);
        SnackbarService.show('Attach failed: $error');
      },
    );
  }

  /// Get media type from filename for analytics
  String _getMediaType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'heic', 'heif', 'webp'].contains(ext)) {
      return 'image';
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return 'video';
    } else if (['mp3', 'wav', 'aac', 'm4a', 'ogg'].contains(ext)) {
      return 'audio';
    } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return 'document';
    }
    return 'other';
  }

  /// Convert HEIC/HEIF images to JPEG
  /// Returns a map with 'bytes' and 'filename' keys
  Future<Map<String, dynamic>> _convertHeicIfNeeded(
    String? filePath,
    dynamic bytes,
    String filename,
  ) async {
    final fileExt = filename.toLowerCase();

    if (!fileExt.contains('.heic') && !fileExt.contains('.heif')) {
      return {'bytes': bytes, 'filename': filename};
    }

    if (kIsWeb) {
      SnackbarService.show(
        'HEIC format is not supported on web. Please convert to JPEG or PNG first, or use a different browser/device.',
        duration: const Duration(seconds: 4),
      );
      throw Exception('HEIC format not supported on web');
    }

    try {
      dynamic compressedBytes;

      if (filePath != null && filePath.isNotEmpty) {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          filePath,
          format: CompressFormat.jpeg,
          quality: 90,
        );
      } else if (bytes != null) {
        compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          format: CompressFormat.jpeg,
          quality: 90,
        );
      } else {
        throw Exception('No file data available for conversion');
      }

      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      final newFilename = filename.replaceAll(
        RegExp(r'\.(heic|heif)$', caseSensitive: false),
        '.jpg',
      );

      return {'bytes': compressedBytes, 'filename': newFilename};
    } catch (e, stackTrace) {
      // Log for debugging but keep user-facing error message
      sl<AppLogger>().error('HEIC conversion failed', tag: 'MediaUploadService', error: e, stackTrace: stackTrace);
      SnackbarService.show('Failed to convert HEIC image: $e');
      rethrow;
    }
  }

  /// Upload file to Firebase Storage with progress tracking
  Future<String> _uploadToStorage({
    required String? filePath,
    required dynamic bytes,
    required String filename,
    required String roomId,
    required String tempId,
    required UploadProgressCallback onProgress,
    required UploadErrorCallback onError,
  }) async {
    final storagePath =
        'chat_attachments/$roomId/${DateTime.now().millisecondsSinceEpoch}_$filename';
    final ref = FirebaseStorage.instance.ref().child(storagePath);

    UploadTask uploadTask;
    if (bytes != null && bytes.isNotEmpty) {
      uploadTask = ref.putData(bytes);
    } else if (filePath != null && filePath.isNotEmpty) {
      uploadTask = ref.putFile(File(filePath));
    } else {
      throw Exception('No file data available for upload');
    }

    // Listen to upload progress
    final uploadSubscription = uploadTask.snapshotEvents.listen(
      (TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(tempId, progress);
      },
      onError: (e) {
        onError(tempId, e);
      },
    );

    try {
      final snapshot = await uploadTask;
      await uploadSubscription.cancel();
      return await snapshot.ref.getDownloadURL();
    } finally {
      if (!uploadSubscription.isPaused) {
        await uploadSubscription.cancel();
      }
    }
  }

  /// Create and send chat message with media attachment
  Future<void> _sendChatMessage({
    required String downloadUrl,
    required String filename,
    required String roomId,
    required int? fileSize,
    required Message? replyToMessage,
  }) async {
    final user = sl<FirebaseAuth>().currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final fileExt = filename.contains('.')
        ? '.${filename.split('.').last.toLowerCase()}'
        : '';
    final messageType = FileTypeHelper.getMessageTypeFromExtension(fileExt);

    // Build metadata for document types
    Map<String, dynamic>? metadata;
    if (messageType == MessageType.doc) {
      metadata = {
        'fileName': filename,
        if (fileSize != null) 'fileSize': fileSize,
      };
    }

    final message = Message(
      id: '',
      senderId: user.uid,
      type: messageType,
      text: filename,
      mediaUrl: downloadUrl,
      replyToMessageId: replyToMessage?.id,
      replyToMessage: replyToMessage,
      timestamp: Timestamp.now(),
      metadata: metadata,
    );

    await _messageRepository.sendMessage(roomId, message);
  }
}
