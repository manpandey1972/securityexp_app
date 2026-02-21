import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/models/upload_state.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/shared/services/media_type_helper.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';
import 'package:securityexperts_app/features/chat/services/media_encryption_service.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';

/// Global upload manager that handles all media uploads.
///
/// This service lives at the app level (registered as singleton in GetIt)
/// so uploads continue even when user navigates away from chat.
///
/// Features:
/// - Multiple simultaneous uploads
/// - Progress tracking for each upload
/// - Uploads continue in background when app is backgrounded
/// - Notifies listeners of state changes
class UploadManager extends ChangeNotifier {
  static const String _tag = 'UploadManager';

  final ChatMessageRepository _messageRepository;
  final MediaEncryptionService? _mediaEncryption;
  final EncryptionService? _encryptionService;
  final AppLogger _log;

  /// Map of upload ID to active upload state
  final Map<String, UploadState> _uploads = {};

  /// Map of upload ID to Firebase UploadTask (for cancellation)
  final Map<String, UploadTask> _uploadTasks = {};

  /// Map of upload ID to stream subscription (for cleanup)
  final Map<String, StreamSubscription> _subscriptions = {};

  UploadManager({
    ChatMessageRepository? messageRepository,
    MediaEncryptionService? mediaEncryption,
    EncryptionService? encryptionService,
    AppLogger? logger,
  })  : _messageRepository = messageRepository ?? sl<ChatMessageRepository>(),
        _mediaEncryption = mediaEncryption,
        _encryptionService = encryptionService,
        _log = logger ?? sl<AppLogger>();

  /// Whether E2EE media encryption is available.
  bool get isE2eeEnabled =>
      _mediaEncryption != null && _encryptionService != null;

  // =========================================================================
  // PUBLIC GETTERS
  // =========================================================================

  /// Get all current uploads (both active and recently completed/failed)
  Map<String, UploadState> get uploads => Map.unmodifiable(_uploads);

  /// Get only active (uploading) uploads
  List<UploadState> get activeUploads =>
      _uploads.values.where((u) => u.isActive).toList();

  /// Get uploads for a specific room
  List<UploadState> getUploadsForRoom(String roomId) =>
      _uploads.values.where((u) => u.roomId == roomId).toList();

  /// Get active uploads for a specific room
  List<UploadState> getActiveUploadsForRoom(String roomId) =>
      _uploads.values.where((u) => u.roomId == roomId && u.isActive).toList();

  /// Whether there are any active uploads
  bool get hasActiveUploads => _uploads.values.any((u) => u.isActive);

  /// Count of active uploads
  int get activeUploadCount => _uploads.values.where((u) => u.isActive).length;

  /// Total progress across all active uploads (0.0 to 1.0)
  double get totalProgress {
    final active = activeUploads;
    if (active.isEmpty) return 0.0;
    final sum = active.fold<double>(0, (sum, u) => sum + u.progress);
    return sum / active.length;
  }

  // =========================================================================
  // PUBLIC METHODS
  // =========================================================================

  /// Start a new upload
  ///
  /// Returns the upload ID that can be used to track or cancel the upload.
  /// This method returns immediately - upload continues in background.
  Future<String> startUpload({
    required String roomId,
    String? filePath,
    Uint8List? bytes,
    required String filename,
    Message? replyToMessage,
  }) async {
    // Validate inputs
    if (roomId.isEmpty) {
      SnackbarService.show('No room available to send attachments');
      throw ArgumentError('roomId cannot be empty');
    }

    if (bytes == null && (filePath == null || filePath.isEmpty)) {
      SnackbarService.show('File data is empty');
      throw ArgumentError('Either bytes or filePath must be provided');
    }

    // Generate unique upload ID
    final uploadId =
        'upload_${DateTime.now().millisecondsSinceEpoch}_${_uploads.length}';

    // Determine message type
    final ext = MediaTypeHelper.getExtension(filename);
    final fileExt = ext.isNotEmpty ? '.$ext' : '';
    final messageType = FileTypeHelper.getMessageTypeFromExtension(fileExt);

    // Create initial upload state
    final uploadState = UploadState(
      id: uploadId,
      roomId: roomId,
      filename: filename,
      type: messageType,
      status: UploadStatus.uploading,
      progress: 0.0,
      replyToMessageId: replyToMessage?.id,
      replyToMessage: replyToMessage,
      startedAt: DateTime.now(),
    );

    // Add to tracking map
    _uploads[uploadId] = uploadState;
    notifyListeners();

    _log.info('Starting upload: $uploadId for file: $filename', tag: _tag);

    // Start upload in background (don't await)
    _performUpload(
      uploadId: uploadId,
      roomId: roomId,
      filePath: filePath,
      bytes: bytes,
      filename: filename,
      replyToMessage: replyToMessage,
    );

    return uploadId;
  }

  /// Cancel an upload
  Future<void> cancelUpload(String uploadId) async {
    _log.info('Cancelling upload: $uploadId', tag: _tag);

    // Cancel Firebase upload task
    final task = _uploadTasks[uploadId];
    if (task != null) {
      await task.cancel();
    }

    // Cancel subscription
    await _subscriptions[uploadId]?.cancel();
    _subscriptions.remove(uploadId);
    _uploadTasks.remove(uploadId);

    // Update state
    final current = _uploads[uploadId];
    if (current != null) {
      _uploads[uploadId] = current.copyWith(status: UploadStatus.cancelled);
      notifyListeners();
    }

    // Remove after short delay to allow UI to show cancelled state
    Future.delayed(const Duration(seconds: 2), () {
      _uploads.remove(uploadId);
      notifyListeners();
    });
  }

  /// Clear completed/failed/cancelled uploads from the list
  void clearCompletedUploads() {
    _uploads.removeWhere((_, u) => !u.isActive);
    notifyListeners();
  }

  /// Clear a specific upload from the list (if not active)
  void removeUpload(String uploadId) {
    final upload = _uploads[uploadId];
    if (upload != null && !upload.isActive) {
      _uploads.remove(uploadId);
      notifyListeners();
    }
  }

  // =========================================================================
  // PRIVATE METHODS
  // =========================================================================

  /// Perform the actual upload
  Future<void> _performUpload({
    required String uploadId,
    required String roomId,
    String? filePath,
    Uint8List? bytes,
    required String filename,
    Message? replyToMessage,
  }) async {
    try {
      // Convert HEIC/HEIF to JPEG if needed
      final convertedResult = await _convertHeicIfNeeded(
        filePath,
        bytes,
        filename,
      );
      bytes = convertedResult['bytes'] as Uint8List?;
      filename = convertedResult['filename'] as String;

      // Ensure we have bytes in memory for E2EE or size calculation
      if (bytes == null || bytes.isEmpty) {
        if (filePath != null && filePath.isNotEmpty) {
          bytes = await File(filePath).readAsBytes();
        } else {
          throw Exception('No file data available for upload');
        }
      }

      final int fileSize = bytes.length;

      // Update filename in state if it changed
      final currentState = _uploads[uploadId];
      if (currentState != null && currentState.filename != filename) {
        _uploads[uploadId] = currentState.copyWith(filename: filename);
        notifyListeners();
      }

      if (isE2eeEnabled) {
        await _performEncryptedUpload(
          uploadId: uploadId,
          roomId: roomId,
          bytes: bytes,
          filename: filename,
          fileSize: fileSize,
          replyToMessage: replyToMessage,
        );
      } else {
        await _performPlaintextUpload(
          uploadId: uploadId,
          roomId: roomId,
          filePath: filePath,
          bytes: bytes,
          filename: filename,
          fileSize: fileSize,
          replyToMessage: replyToMessage,
        );
      }

      // Update state to completed
      final current = _uploads[uploadId];
      if (current != null) {
        _uploads[uploadId] = current.copyWith(
          status: UploadStatus.completed,
          progress: 1.0,
        );
        notifyListeners();
        _log.info('Upload completed: $uploadId', tag: _tag);
      }

      // Remove completed upload after delay
      Future.delayed(const Duration(seconds: 3), () {
        _uploads.remove(uploadId);
        _uploadTasks.remove(uploadId);
        _subscriptions.remove(uploadId);
        notifyListeners();
      });
    } catch (e, stackTrace) {
      _log.error('Upload failed: $uploadId - $e', tag: _tag, stackTrace: stackTrace);

      // Update state to failed
      final current = _uploads[uploadId];
      if (current != null && current.status != UploadStatus.cancelled) {
        _uploads[uploadId] = current.copyWith(
          status: UploadStatus.failed,
          error: e.toString(),
        );
        notifyListeners();
        SnackbarService.show('Upload failed: ${current.filename}');
      }

      // Cleanup
      _uploadTasks.remove(uploadId);
      await _subscriptions[uploadId]?.cancel();
      _subscriptions.remove(uploadId);
    }
  }

  /// Plaintext upload flow (no E2EE).
  Future<void> _performPlaintextUpload({
    required String uploadId,
    required String roomId,
    String? filePath,
    required Uint8List bytes,
    required String filename,
    required int fileSize,
    Message? replyToMessage,
  }) async {
    final downloadUrl = await _uploadToStorage(
      uploadId: uploadId,
      filePath: filePath,
      bytes: bytes,
      filename: filename,
      roomId: roomId,
    );

    await _sendChatMessage(
      downloadUrl: downloadUrl,
      filename: filename,
      roomId: roomId,
      fileSize: fileSize,
      replyToMessage: replyToMessage,
    );
  }

  /// Encrypted upload flow (E2EE).
  ///
  /// 1. Encrypt file bytes with a random AES-256-GCM key
  /// 2. Upload encrypted blob to `encrypted_media/` with a UUID filename
  /// 3. Build [DecryptedContent] with media key, hash, URL
  /// 4. Encrypt via Signal Protocol then store in Firestore
  Future<void> _performEncryptedUpload({
    required String uploadId,
    required String roomId,
    required Uint8List bytes,
    required String filename,
    required int fileSize,
    Message? replyToMessage,
  }) async {
    _log.info('Starting encrypted upload: $uploadId', tag: _tag);

    // 1. Encrypt the file
    final result = await _mediaEncryption!.encryptFile(bytes);

    // 2. Generate a random UUID-based storage path (no real filename)
    final uuid = _generateUuid();
    final storagePath = 'encrypted_media/$roomId/$uuid.enc';
    final ref = FirebaseStorage.instance.ref().child(storagePath);

    // Upload encrypted bytes
    final uploadTask = ref.putData(
      result.encryptedBytes,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    _uploadTasks[uploadId] = uploadTask;

    final subscription = uploadTask.snapshotEvents.listen(
      (TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _updateProgress(uploadId, progress);
      },
      onError: (e, stackTrace) {
        _log.error('Encrypted upload stream error: $uploadId - $e',
            tag: _tag, stackTrace: stackTrace);
      },
    );
    _subscriptions[uploadId] = subscription;

    final snapshot = await uploadTask;
    await subscription.cancel();
    _subscriptions.remove(uploadId);

    final encryptedUrl = await snapshot.ref.getDownloadURL();

    // 3. Determine MIME type from filename
    final ext = MediaTypeHelper.getExtension(filename);
    final fileExt = ext.isNotEmpty ? '.$ext' : '';
    final messageType = FileTypeHelper.getMessageTypeFromExtension(fileExt);
    final mimeType = _getMimeType(filename);

    // 4. Build DecryptedContent with all media metadata
    final content = DecryptedContent(
      text: filename,
      mediaUrl: encryptedUrl,
      mediaKey: result.mediaKey,
      mediaHash: result.mediaHash,
      mediaType: mimeType,
      mediaSize: result.originalSize,
      fileName: messageType == MessageType.doc ? filename : null,
      replyToMessageId: replyToMessage?.id,
      metadata: messageType == MessageType.doc
          ? {'fileName': filename, 'fileSize': fileSize}
          : null,
    );

    // 5. Encrypt via Signal Protocol and send
    final user = sl<FirebaseAuth>().currentUser;
    if (user == null) throw Exception('User not authenticated');

    final recipientId = _deriveRecipientId(roomId, user.uid);

    final encryptedMessage = await _encryptionService!.encryptMessage(
      remoteUserId: recipientId,
      messageType: messageType.toJson(),
      content: content,
    );

    // 6. Write encrypted message to Firestore
    await _messageRepository.sendEncryptedMediaMessage(
      roomId: roomId,
      encryptedMessage: encryptedMessage,
      senderId: user.uid,
      messageType: messageType,
    );

    _log.info('Encrypted upload sent: $uploadId', tag: _tag);
  }

  /// Derive the recipient user ID from a room ID.
  String _deriveRecipientId(String roomId, String senderId) {
    final parts = roomId.split('_');
    return parts[0] == senderId ? parts[1] : parts[0];
  }

  /// Generate a UUID v4-like random string.
  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.hashCode ^ Object().hashCode;
    return '${now.toRadixString(36)}_${random.abs().toRadixString(36)}';
  }

  /// Get MIME type from filename extension.
  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      'doc' || 'docx' => 'application/msword',
      'xls' || 'xlsx' => 'application/vnd.ms-excel',
      'ppt' || 'pptx' => 'application/vnd.ms-powerpoint',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  /// Upload file to Firebase Storage with progress tracking
  Future<String> _uploadToStorage({
    required String uploadId,
    String? filePath,
    Uint8List? bytes,
    required String filename,
    required String roomId,
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

    // Store task for potential cancellation
    _uploadTasks[uploadId] = uploadTask;

    // Listen to upload progress
    final subscription = uploadTask.snapshotEvents.listen(
      (TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _updateProgress(uploadId, progress);
      },
      onError: (e, stackTrace) {
        _log.error('Upload stream error: $uploadId - $e', tag: _tag, stackTrace: stackTrace);
      },
    );
    _subscriptions[uploadId] = subscription;

    try {
      final snapshot = await uploadTask;
      await subscription.cancel();
      _subscriptions.remove(uploadId);
      return await snapshot.ref.getDownloadURL();
    } catch (e, stackTrace) {
      _log.error('Upload storage error: $e', tag: _tag, stackTrace: stackTrace);
      await subscription.cancel();
      _subscriptions.remove(uploadId);
      rethrow;
    }
  }

  /// Update progress for an upload
  void _updateProgress(String uploadId, double progress) {
    final current = _uploads[uploadId];
    if (current != null && current.status == UploadStatus.uploading) {
      _uploads[uploadId] = current.copyWith(progress: progress);
      notifyListeners();
    }
  }

  /// Send chat message after upload completes
  Future<void> _sendChatMessage({
    required String downloadUrl,
    required String filename,
    required String roomId,
    required int? fileSize,
    Message? replyToMessage,
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

  /// Convert HEIC/HEIF images to JPEG
  Future<Map<String, dynamic>> _convertHeicIfNeeded(
    String? filePath,
    Uint8List? bytes,
    String filename,
  ) async {
    final fileExt = filename.toLowerCase();

    if (!fileExt.contains('.heic') && !fileExt.contains('.heif')) {
      return {'bytes': bytes, 'filename': filename};
    }

    if (kIsWeb) {
      SnackbarService.show(
        'HEIC format is not supported on web.',
        duration: const Duration(seconds: 4),
      );
      throw Exception('HEIC format not supported on web');
    }

    try {
      Uint8List? compressedBytes;

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
      _log.error('Failed to convert HEIC image: $e', tag: _tag, stackTrace: stackTrace);
      SnackbarService.show('Failed to convert HEIC image: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    // Cancel all active uploads
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _uploadTasks.clear();
    _uploads.clear();
    super.dispose();
  }
}
