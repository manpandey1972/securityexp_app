import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// Repository for handling support ticket attachments.
///
/// Manages uploading files to Firebase Storage and generating
/// download URLs for ticket attachments.
class SupportAttachmentRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AppLogger _log = sl<AppLogger>();
  final _uuid = const Uuid();

  static const String _tag = 'SupportAttachmentRepository';
  static const String _basePath = 'support';
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  // Allowed MIME types
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'text/plain',
  ];

  /// Upload multiple pending attachments for a ticket (web-compatible).
  ///
  /// Returns a list of [TicketAttachment] objects with URLs, or null on failure.
  Future<List<TicketAttachment>?> uploadPendingAttachments({
    required String ticketId,
    required List<PendingAttachment> attachments,
    String? subPath,
    void Function(double progress)? onProgress,
  }) async {
    if (attachments.isEmpty) {
      return [];
    }

    return await ErrorHandler.handle<List<TicketAttachment>?>(
      operation: () async {
        final uploadedAttachments = <TicketAttachment>[];
        var completedFiles = 0;

        for (final pending in attachments) {
          final attachment = await _uploadPendingAttachment(
            ticketId: ticketId,
            pending: pending,
            subPath: subPath,
            onProgress: (fileProgress) {
              if (onProgress != null) {
                final overallProgress =
                    (completedFiles + fileProgress) / attachments.length;
                onProgress(overallProgress);
              }
            },
          );

          if (attachment != null) {
            uploadedAttachments.add(attachment);
          }
          completedFiles++;
        }

        _log.info(
          'Uploaded ${uploadedAttachments.length}/${attachments.length} attachments for ticket $ticketId',
          tag: _tag,
        );

        return uploadedAttachments;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error uploading attachments: $error', tag: _tag),
    );
  }

  /// Upload multiple attachments for a ticket.
  ///
  /// Returns a list of [TicketAttachment] objects with URLs, or null on failure.
  Future<List<TicketAttachment>?> uploadAttachments({
    required String ticketId,
    required List<File> files,
    String? subPath,
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) {
      return [];
    }

    return await ErrorHandler.handle<List<TicketAttachment>?>(
      operation: () async {
        final attachments = <TicketAttachment>[];
        var completedFiles = 0;

        for (final file in files) {
          final attachment = await _uploadSingleFile(
            ticketId: ticketId,
            file: file,
            subPath: subPath,
            onProgress: (fileProgress) {
              if (onProgress != null) {
                // Calculate overall progress
                final overallProgress =
                    (completedFiles + fileProgress) / files.length;
                onProgress(overallProgress);
              }
            },
          );

          if (attachment != null) {
            attachments.add(attachment);
          }
          completedFiles++;
        }

        _log.info(
          'Uploaded ${attachments.length}/${files.length} attachments for ticket $ticketId',
          tag: _tag,
        );

        return attachments;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error uploading attachments: $error', tag: _tag),
    );
  }

  /// Upload a single file and return the attachment info.
  Future<TicketAttachment?> _uploadSingleFile({
    required String ticketId,
    required File file,
    String? subPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Validate file exists (skip on web)
      if (!kIsWeb && !await file.exists()) {
        _log.error('File does not exist: ${file.path}', tag: _tag);
        return null;
      }

      // Get file size and read bytes for web
      late final int fileSize;
      Uint8List? fileBytes;
      
      if (kIsWeb) {
        // On web, read the file as bytes
        try {
          fileBytes = await file.readAsBytes();
          fileSize = fileBytes.length;
        } catch (e) {
          _log.error('Failed to read file on web: $e', tag: _tag);
          return null;
        }
      } else {
        fileSize = await file.length();
      }
      
      if (fileSize > maxFileSizeBytes) {
        _log.error(
          'File too large: ${fileSize / (1024 * 1024)}MB > ${maxFileSizeBytes / (1024 * 1024)}MB',
          tag: _tag,
        );
        return null;
      }

      // Generate unique ID and path
      final attachmentId = _uuid.v4();
      final fileName = path.basename(file.path);
      final extension = path.extension(fileName).toLowerCase();
      final storagePath = _buildStoragePath(
        ticketId: ticketId,
        attachmentId: attachmentId,
        extension: extension,
        subPath: subPath,
      );

      // Determine MIME type
      final mimeType = _getMimeType(extension);

      // Upload file
      final ref = _storage.ref(storagePath);
      final UploadTask uploadTask;
      
      if (kIsWeb && fileBytes != null) {
        // Use putData for web
        uploadTask = ref.putData(
          fileBytes,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {'ticketId': ticketId, 'originalFileName': fileName},
          ),
        );
      } else {
        // Use putFile for native platforms
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {'ticketId': ticketId, 'originalFileName': fileName},
          ),
        );
      }

      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final url = await snapshot.ref.getDownloadURL();

      return TicketAttachment(
        id: attachmentId,
        url: url,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        uploadedAt: DateTime.now(),
      );
    } catch (e) {
      _log.error('Error uploading file: $e', tag: _tag);
      return null;
    }
  }

  /// Upload a pending attachment (web-compatible).
  Future<TicketAttachment?> _uploadPendingAttachment({
    required String ticketId,
    required PendingAttachment pending,
    String? subPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Get file size
      final fileSize = pending.bytes?.length ?? 0;
      
      if (fileSize == 0 && pending.filePath != null) {
        // Try to get size from file path on native
        final file = File(pending.filePath!);
        if (!await file.exists()) {
          _log.error('File does not exist: ${pending.filePath}', tag: _tag);
          return null;
        }
        final nativeFileSize = await file.length();
        if (nativeFileSize > maxFileSizeBytes) {
          _log.error(
            'File too large: ${nativeFileSize / (1024 * 1024)}MB > ${maxFileSizeBytes / (1024 * 1024)}MB',
            tag: _tag,
          );
          return null;
        }
      } else if (fileSize > maxFileSizeBytes) {
        _log.error(
          'File too large: ${fileSize / (1024 * 1024)}MB > ${maxFileSizeBytes / (1024 * 1024)}MB',
          tag: _tag,
        );
        return null;
      }

      // Generate unique ID and path
      final attachmentId = _uuid.v4();
      final fileName = pending.filename;
      final extension = path.extension(fileName).toLowerCase();
      final storagePath = _buildStoragePath(
        ticketId: ticketId,
        attachmentId: attachmentId,
        extension: extension,
        subPath: subPath,
      );

      // Determine MIME type
      final mimeType = _getMimeType(extension);

      // Upload file
      final ref = _storage.ref(storagePath);
      final UploadTask uploadTask;
      
      if (pending.bytes != null) {
        // Use putData for web or when bytes are available
        uploadTask = ref.putData(
          pending.bytes!,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {'ticketId': ticketId, 'originalFileName': fileName},
          ),
        );
      } else if (pending.filePath != null) {
        // Use putFile for native platforms
        uploadTask = ref.putFile(
          File(pending.filePath!),
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {'ticketId': ticketId, 'originalFileName': fileName},
          ),
        );
      } else {
        _log.error('No bytes or filePath available for upload', tag: _tag);
        return null;
      }

      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final url = await snapshot.ref.getDownloadURL();

      return TicketAttachment(
        id: attachmentId,
        url: url,
        fileName: fileName,
        fileSize: fileSize > 0 ? fileSize : await snapshot.ref.getMetadata().then((m) => m.size ?? 0),
        mimeType: mimeType,
        uploadedAt: DateTime.now(),
      );
    } catch (e) {
      _log.error('Error uploading pending attachment: $e', tag: _tag);
      return null;
    }
  }

  /// Build the storage path for an attachment.
  String _buildStoragePath({
    required String ticketId,
    required String attachmentId,
    required String extension,
    String? subPath,
  }) {
    if (subPath != null) {
      return '$_basePath/$ticketId/$subPath/$attachmentId$extension';
    }
    return '$_basePath/$ticketId/$attachmentId$extension';
  }

  /// Get MIME type from file extension.
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get the download URL for an attachment.
  Future<String?> getDownloadUrl(String storagePath) async {
    return await ErrorHandler.handle<String?>(
      operation: () async {
        final ref = _storage.ref(storagePath);
        return await ref.getDownloadURL();
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error getting download URL: $error', tag: _tag),
    );
  }

  /// Delete an attachment from storage.
  Future<bool> deleteAttachment(String storagePath) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final ref = _storage.ref(storagePath);
        await ref.delete();
        _log.info('Deleted attachment: $storagePath', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error deleting attachment: $error', tag: _tag),
    );
  }

  /// Delete all attachments for a ticket.
  Future<bool> deleteTicketAttachments(String ticketId) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final ref = _storage.ref('$_basePath/$ticketId');
        final listResult = await ref.listAll();

        for (final item in listResult.items) {
          await item.delete();
        }

        // Also delete items in subdirectories
        for (final prefix in listResult.prefixes) {
          final subResult = await prefix.listAll();
          for (final item in subResult.items) {
            await item.delete();
          }
        }

        _log.info('Deleted all attachments for ticket: $ticketId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error deleting ticket attachments: $error', tag: _tag),
    );
  }

  /// Validate that a file can be uploaded.
  Future<String?> validateFile(File file) async {
    // Check if file exists
    if (!await file.exists()) {
      return 'File does not exist';
    }

    // Check file size
    final fileSize = await file.length();
    if (fileSize > maxFileSizeBytes) {
      return 'File is too large (max ${maxFileSizeBytes ~/ (1024 * 1024)}MB)';
    }

    // Check file extension
    final extension = path.extension(file.path).toLowerCase();
    final mimeType = _getMimeType(extension);
    if (!allowedMimeTypes.contains(mimeType) &&
        mimeType == 'application/octet-stream') {
      return 'File type not supported';
    }

    return null; // Valid
  }
}
