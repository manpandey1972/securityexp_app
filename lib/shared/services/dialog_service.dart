import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';

/// Unified service for showing standardized dialogs
/// Consolidates all dialog patterns used throughout the app
class DialogService {
  /// Show a standard text input dialog for editing
  static Future<String?> showEditDialog(
    BuildContext context, {
    required String title,
    required String initialText,
    required String saveButtonLabel,
    int maxLines = 5,
  }) async {
    final controller = TextEditingController(text: initialText);
    String? result;

    if (!context.mounted) return result;

    await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        content: TextField(
          controller: controller,
          style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Enter text',
            hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              result = controller.text;
              Navigator.pop(dialogContext);
            },
            child: Text(
              saveButtonLabel,
              style: AppTypography.bodyRegular.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  /// Show a confirmation dialog with custom actions
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        content: Text(
          message,
          style: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              cancelLabel,
              style: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: AppTypography.bodyRegular.copyWith(
                color: isDestructive ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show an info dialog with a single action
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'OK',
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        content: Text(
          message,
          style: AppTypography.bodyRegular.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              buttonLabel,
              style: AppTypography.bodyRegular.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Show an error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String error,
  }) => showInfoDialog(
    context,
    title: title,
    message: error,
    buttonLabel: 'Dismiss',
  );

  /// Show a loading dialog
  static void showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dismiss a dialog (typically a loading dialog)
  static void dismissDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
