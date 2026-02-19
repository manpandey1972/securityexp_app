import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';
import '../themes/app_typography.dart';
import '../themes/app_icon_sizes.dart';
import 'app_button_variants.dart';

/// Material Design 3 compliant dialog wrapper
/// Provides consistent dialog styling across the app
class AppDialog {
  /// Show a standard material dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        elevation: 8,
        title: Text(
          title,
          style: AppTypography.headingSmall.copyWith(
            letterSpacing: 0.25,
          ),
        ),
        content: contentWidget ??
            (content != null
                ? SingleChildScrollView(
                    child: Text(
                      content,
                      style: AppTypography.bodyRegular.copyWith(
                        height: 1.5,
                      ),
                    ),
                  )
                : null),
        actions: actions ?? [],
      ),
    );
  }

  /// Show a confirmation dialog with Yes/No buttons
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      content: message,
      barrierDismissible: false,
      actions: [
        AppButtonVariants.dialogCancel(
          onPressed: () => Navigator.pop(context, false),
          label: cancelLabel,
        ),
        AppButtonVariants.dialogAction(
          onPressed: () => Navigator.pop(context, true),
          label: confirmLabel,
          isDestructive: isDestructive,
          isPrimary: !isDestructive,
        ),
      ],
    );
  }

  /// Show an error dialog
  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    return show(
      context: context,
      title: title,
      content: message,
      actions: [
        AppButtonVariants.dialogAction(
          onPressed: () {
            Navigator.pop(context);
            onDismiss?.call();
          },
          label: 'OK',
          isPrimary: true,
        ),
      ],
    );
  }

  /// Show a success dialog
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    return show(
      context: context,
      title: title,
      content: message,
      actions: [
        AppButtonVariants.dialogAction(
          onPressed: () {
            Navigator.pop(context);
            onDismiss?.call();
          },
          label: 'OK',
          isPrimary: true,
        ),
      ],
    );
  }

  /// Show a custom full-screen dialog
  static Future<T?> showFullScreen<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    VoidCallback? onClose,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              title,
              style: AppTypography.headingSmall,
            ),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
                onClose?.call();
              },
            ),
            actions: actions,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.spacing16),
            child: content,
          ),
        ),
      ),
    );
  }

  /// Show a custom dialog with title, content, and single action
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonLabel = 'OK',
    IconData? icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        elevation: 8,
        icon: icon != null
            ? Icon(
                icon,
                size: AppIconSizes.display,
                color: AppColors.primary,
              )
            : null,
        title: Text(
          title,
          style: AppTypography.headingSmall,
        ),
        content: Text(
          message,
          style: AppTypography.bodyRegular.copyWith(
            height: 1.5,
          ),
        ),
        actions: [
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.pop(context),
            label: buttonLabel,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}
