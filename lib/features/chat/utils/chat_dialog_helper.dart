import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/shared/services/dialog_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';

/// Helper class for chat-related dialogs
class ChatDialogHelper {
  /// Show edit message dialog with validation and error handling
  static Future<String?> showEditMessageDialog(
    BuildContext context,
    Message message,
    String originalText,
    ChatMessageRepository messageRepository,
    String roomId,
  ) async {
    if (!context.mounted) return null;

    final editedText = await DialogService.showEditDialog(
      context,
      title: 'Edit Message',
      initialText: originalText,
      saveButtonLabel: 'Save',
      maxLines: 5,
    );

    if (editedText == null || editedText.isEmpty) return null;

    // Check if text actually changed
    if (editedText.trim() == originalText.trim()) {
      if (context.mounted) {
        SnackbarService.show('No changes made');
      }
      return null;
    }

    if (!context.mounted) return null;
    DialogService.showLoadingDialog(context, message: 'Updating message...');

    String? result;
    await ErrorHandler.handle<void>(
      operation: () async {
        await messageRepository.updateMessage(
          roomId,
          message.id,
          editedText.trim(),
        );
        result = editedText.trim();
        if (context.mounted) {
          DialogService.dismissDialog(context);
          SnackbarService.show('Message updated');
        }
      },
      fallback: null,
      onError: (error) {
        if (context.mounted) {
          DialogService.dismissDialog(context);
          DialogService.showErrorDialog(
            context,
            title: 'Update Error',
            error: 'Failed to update message: $error',
          );
        }
      },
    );

    return result;
  }
}
