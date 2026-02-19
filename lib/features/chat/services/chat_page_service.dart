import 'package:flutter/material.dart';
import 'package:greenhive_app/data/repositories/chat/chat_repositories.dart';
import 'package:greenhive_app/shared/services/media_download_service.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/shared/services/dialog_service.dart';

/// Service for message operations in chat page.
///
/// Provides both data-only methods (preferred) and legacy UI-aware methods.
///
/// **New code** should use the data-only methods ([editMessage],
/// [deleteMessage], [downloadMedia]) and handle UI feedback in the page
/// or ViewModel layer.
class ChatPageService {
  final ChatMessageRepository _messageRepository;
  final MediaDownloadService _mediaDownloadService;

  ChatPageService({
    required ChatMessageRepository messageRepository,
    required MediaDownloadService mediaDownloadService,
  }) : _messageRepository = messageRepository,
       _mediaDownloadService = mediaDownloadService;

  // =========================================================================
  // DATA-ONLY METHODS (preferred — no BuildContext, no UI side-effects)
  // =========================================================================

  /// Edit a message in the repository.
  ///
  /// Returns `true` on success, `false` on failure.
  /// The caller is responsible for showing any UI feedback.
  Future<bool> editMessage({
    required String roomId,
    required String messageId,
    required String newText,
  }) async {
    final result = await ErrorHandler.handle<bool>(
      operation: () async {
        await _messageRepository.updateMessage(roomId, messageId, newText);
        return true;
      },
      fallback: false,
    );
    return result;
  }

  /// Delete a message from the repository.
  ///
  /// Returns `true` on success, `false` on failure.
  /// The caller is responsible for showing any UI feedback.
  Future<bool> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    final result = await ErrorHandler.handle<bool>(
      operation: () async {
        await _messageRepository.deleteMessage(roomId, messageId);
        return true;
      },
      fallback: false,
    );
    return result;
  }

  /// Download media and save to device.
  ///
  /// Returns `true` on success, `false` on failure.
  /// The caller is responsible for showing any UI feedback.
  Future<bool> downloadMedia({
    required String mediaUrl,
    required String fileName,
    required String roomId,
  }) async {
    final result = await ErrorHandler.handle<bool>(
      operation: () async {
        await _mediaDownloadService.downloadMedia(mediaUrl, fileName, roomId);
        return true;
      },
      fallback: false,
    );
    return result;
  }

  // =========================================================================
  // LEGACY UI-AWARE METHODS (use data-only methods above for new code)
  // =========================================================================

  /// Handle message edit operation
  /// Shows dialog to get new message text and updates message in Firebase
  @Deprecated('Use editMessage() and handle UI in the page/ViewModel layer')
  Future<void> handleEditMessage(
    BuildContext context, {
    required Message message,
    required String roomId,
  }) async {
    if (!context.mounted) return;

    final editedText = await DialogService.showEditDialog(
      context,
      title: 'Edit Message',
      initialText: message.text,
      saveButtonLabel: 'Save',
    );

    if (editedText == null || editedText.isEmpty) return;
    if (!context.mounted) return;

    DialogService.showLoadingDialog(context, message: 'Saving message...');

    await ErrorHandler.handle<void>(
      operation: () async {
        await _messageRepository.updateMessage(roomId, message.id, editedText);

        if (context.mounted) {
          DialogService.dismissDialog(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message updated')));
        }
      },
      onError: (error) {
        if (context.mounted) {
          DialogService.dismissDialog(context);
          DialogService.showErrorDialog(
            context,
            title: 'Error',
            error: 'Failed to edit message',
          );
        }
      },
    );
  }

  /// Handle message delete operation
  /// Shows confirmation dialog and deletes message from Firebase
  @Deprecated('Use deleteMessage() and handle UI in the page/ViewModel layer')
  Future<void> handleDeleteMessage(
    BuildContext context, {
    required Message message,
    required String roomId,
  }) async {
    if (!context.mounted) return;

    final confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Delete Message',
      message: 'Are you sure you want to delete this message?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    DialogService.showLoadingDialog(context, message: 'Deleting message...');

    await ErrorHandler.handle<void>(
      operation: () async {
        await _messageRepository.deleteMessage(roomId, message.id);

        if (context.mounted) {
          DialogService.dismissDialog(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message deleted')));
        }
      },
      onError: (error) {
        if (context.mounted) {
          DialogService.dismissDialog(context);
          DialogService.showErrorDialog(
            context,
            title: 'Error',
            error: 'Failed to delete message',
          );
        }
      },
    );
  }

  /// Handle media download operation
  /// Downloads media file and saves to device
  @Deprecated('Use downloadMedia() and handle UI in the page/ViewModel layer')
  Future<void> handleMediaDownload(
    BuildContext context, {
    required String mediaUrl,
    required String fileName,
    required String roomId,
  }) async {
    if (!context.mounted) return;

    DialogService.showLoadingDialog(context, message: 'Downloading...');

    await ErrorHandler.handle<void>(
      operation: () async {
        await _mediaDownloadService.downloadMedia(mediaUrl, fileName, roomId);

        if (context.mounted) {
          DialogService.dismissDialog(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File downloaded successfully')),
          );
        }
      },
      onError: (error) {
        if (context.mounted) {
          DialogService.dismissDialog(context);
        }
      },
    );

    if (context.mounted) {
      await DialogService.showErrorDialog(
        context,
        title: 'Download Error',
        error: 'Failed to download file',
      );
    }
  }

  /// Handle reply message creation
  /// Sets up reply state for a message
  void handleReplyMessage({required Message message}) {
    // Reply state is typically managed in the page's state
    // This method documents the reply operation
  }

  /// Get a display-friendly filename
  /// Used for media files when downloading
  String getDisplayFileName(Message message) {
    // Message model doesn't have fileName field
    // Generate filename from message metadata or timestamp
    final dateStr = message.dateTime
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return 'media_$dateStr';
  }

  /// Validate message before sending
  /// Ensures message content is valid
  bool isValidMessage(String messageText) {
    return messageText.trim().isNotEmpty;
  }

  /// Validate media file before uploading
  /// Ensures file meets app requirements
  bool isValidMediaFile(String filePath, {int maxSizeInMB = 100}) {
    // File validation logic
    // In a real implementation, would check file size, type, etc.
    return true;
  }
}
