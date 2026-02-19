import 'package:flutter/material.dart';
import '../themes/app_button_sizes.dart';
import '../themes/app_typography.dart';
import '../themes/app_colors.dart';

/// Convenient button wrapper functions for common button sizes and styles
/// Reduces boilerplate by providing pre-configured button shortcuts
class AppButtonVariants {
  /// Small elevated button (32px height)
  static Widget elevatedSmall({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: AppButtonSizes.smallHeight,
      child: ElevatedButton.icon(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                height: AppButtonSizes.iconSmall,
                width: AppButtonSizes.iconSmall,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : (icon != null ? Icon(icon, size: AppButtonSizes.iconSmall) : const SizedBox.shrink()),
        label: Text(label, style: AppTypography.bodySmall),
      ),
    );
  }

  /// Large elevated button (56px height)
  static Widget elevatedLarge({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: AppButtonSizes.largeHeight,
      child: ElevatedButton.icon(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                height: AppButtonSizes.iconMedium,
                width: AppButtonSizes.iconMedium,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              )
            : (icon != null ? Icon(icon, size: AppButtonSizes.iconMedium) : const SizedBox.shrink()),
        label: Text(label, style: AppTypography.bodyRegular),
      ),
    );
  }

  /// Full-width elevated button
  static Widget elevatedFullWidth({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    double height = 44,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : (icon != null ? Icon(icon, size: AppButtonSizes.iconSmall) : const SizedBox.shrink()),
        label: Text(label, style: AppTypography.bodyRegular),
      ),
    );
  }

  /// Small outlined button (32px height)
  static Widget outlinedSmall({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: AppButtonSizes.smallHeight,
      child: OutlinedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: AppButtonSizes.iconSmall) : const SizedBox.shrink(),
        label: Text(label, style: AppTypography.bodySmall),
      ),
    );
  }

  /// Large outlined button (56px height)
  static Widget outlinedLarge({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: AppButtonSizes.largeHeight,
      child: OutlinedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: AppButtonSizes.iconMedium) : const SizedBox.shrink(),
        label: Text(label, style: AppTypography.bodyRegular),
      ),
    );
  }

  /// Full-width outlined button
  static Widget outlinedFullWidth({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    double height = 44,
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: AppButtonSizes.iconSmall) : const SizedBox.shrink(),
        label: Text(label, style: AppTypography.bodyRegular),
      ),
    );
  }

  /// Small text button (32px height)
  static Widget textSmall({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: AppButtonSizes.smallHeight,
      child: TextButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: AppButtonSizes.iconSmall) : const SizedBox.shrink(),
        label: Text(label, style: AppTypography.bodySmall),
      ),
    );
  }

  /// Large text button (56px height)
  static Widget textLarge({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: AppButtonSizes.largeHeight,
      child: TextButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: AppButtonSizes.iconMedium) : const SizedBox.shrink(),
        label: Text(label, style: AppTypography.bodyRegular),
      ),
    );
  }

  /// Full-width text button
  static Widget textFullWidth({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
    double height = 44,
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: AppButtonSizes.iconSmall) : const SizedBox.shrink(),
        label: Text(label, style: AppTypography.bodyRegular),
      ),
    );
  }

  /// Icon button wrapper for consistency
  static Widget iconButton({
    required VoidCallback onPressed,
    required IconData icon,
    double size = 24,
    Color? color,
    bool isEnabled = true,
  }) {
    return IconButton(
      onPressed: isEnabled ? onPressed : null,
      icon: Icon(icon, size: size, color: color),
      tooltip: '',
    );
  }

  /// Primary action button - full width with loading state
  /// Most common pattern for form submission and primary actions
  static Widget primary({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
    bool isEnabled = true,
    double height = 48,
  }) {
    final effectiveOnPressed = (isEnabled && !isLoading) ? onPressed : null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: AppTypography.bodyEmphasis),
      ),
    );
  }

  /// Secondary action button - outlined, full width with loading state
  /// Used for secondary actions like "Skip", "Cancel", etc.
  static Widget secondary({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
    bool isEnabled = true,
    double height = 48,
  }) {
    final effectiveOnPressed = (isEnabled && !isLoading) ? onPressed : null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: effectiveOnPressed,
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: AppTypography.bodyEmphasis),
      ),
    );
  }

  /// Destructive action button - for delete, remove, cancel actions
  static Widget destructive({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
    bool isEnabled = true,
    double height = 48,
  }) {
    final effectiveOnPressed = (isEnabled && !isLoading) ? onPressed : null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
        ),
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: AppTypography.bodyEmphasis),
      ),
    );
  }

  /// Dialog action button - used in AlertDialog actions
  static Widget dialogAction({
    required VoidCallback onPressed,
    required String label,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.bodyRegular.copyWith(
          color: isDestructive
              ? AppColors.error
              : isPrimary
                  ? AppColors.primary
                  : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Dialog cancel button - standard "Cancel" button for dialogs
  static Widget dialogCancel({
    required VoidCallback onPressed,
    String label = 'Cancel',
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.bodyRegular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Compact button for tight spaces (app bar, list items)
  static Widget compact({
    required VoidCallback onPressed,
    required String label,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return ElevatedButton(
      onPressed: (isEnabled && !isLoading) ? onPressed : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: isLoading
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: AppTypography.bodySmall),
    );
  }

  /// Action button with icon - for retry, refresh, and similar actions
  /// Used in empty states, error states, etc.
  static Widget actionWithIcon({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: (isEnabled && !isLoading) ? onPressed : null,
      icon: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label, style: AppTypography.bodyRegular),
    );
  }

  /// Dialog confirm button - styled primary action for dialogs
  /// Use for "Send", "Save", "Confirm" type actions
  static Widget dialogConfirm({
    required VoidCallback onPressed,
    required String label,
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.bodyRegular.copyWith(
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// Dialog destructive button - for delete/discard actions in dialogs
  static Widget dialogDestructive({
    required VoidCallback onPressed,
    required String label,
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.bodyRegular.copyWith(
          color: AppColors.error,
        ),
      ),
    );
  }
}
