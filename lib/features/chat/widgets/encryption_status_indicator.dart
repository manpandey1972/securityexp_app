import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// A compact indicator showing end-to-end encryption status.
///
/// Displays a lock icon with optional label text. Used in:
/// - Chat app bar subtitle area (full mode with text)
/// - Message bubble timestamp row (icon-only mode)
class EncryptionStatusIndicator extends StatelessWidget {
  /// Whether E2EE is enabled for this conversation.
  final bool isEnabled;

  /// Whether to show the label text alongside the icon.
  /// Defaults to true (full mode for app bar).
  final bool showLabel;

  /// Icon size override.
  final double iconSize;

  /// Optional text style override.
  final TextStyle? textStyle;

  const EncryptionStatusIndicator({
    super.key,
    required this.isEnabled,
    this.showLabel = true,
    this.iconSize = 12.0,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return const SizedBox.shrink();

    final style = textStyle ??
        AppTypography.captionTiny.copyWith(
          color: AppColors.textSecondary,
        );

    if (!showLabel) {
      return Icon(
        Icons.lock_rounded,
        size: iconSize,
        color: AppColors.textSecondary,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_rounded,
          size: iconSize,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 3),
        Text('End-to-end encrypted', style: style),
      ],
    );
  }
}

/// A small lock icon badge shown on individual encrypted messages.
///
/// Placed next to the timestamp in the message bubble footer.
class MessageEncryptionBadge extends StatelessWidget {
  /// Whether this specific message is encrypted.
  final bool isEncrypted;

  /// Whether decryption failed for this message.
  final bool decryptionFailed;

  const MessageEncryptionBadge({
    super.key,
    required this.isEncrypted,
    this.decryptionFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEncrypted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Icon(
        decryptionFailed ? Icons.lock_open_rounded : Icons.lock_rounded,
        size: 10,
        color: decryptionFailed
            ? AppColors.error
            : AppColors.textSecondary,
      ),
    );
  }
}
