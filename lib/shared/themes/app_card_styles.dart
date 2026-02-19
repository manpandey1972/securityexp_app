import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Card style variants for consistent card styling across the app.
/// Provides three main variants: elevated, filled, and outlined.
class AppCardStyle {
  AppCardStyle._(); // Private constructor to prevent instantiation

  // ====================
  // Elevated Card Style
  // ====================
  /// Elevated card with shadow - most prominent, used for important content
  static BoxDecoration get elevated => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ====================
  // Filled Card Style
  // ====================
  /// Filled card with subtle border - standard, used for most content
  static BoxDecoration get filled => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      );

  // ====================
  // Outlined Card Style
  // ====================
  /// Outlined card - minimal, used for supporting content or secondary information
  static BoxDecoration get outlined => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      );

  // ====================
  // Subtle Card Style
  // ====================
  /// Subtle card with no border - minimal, used for large content areas
  static BoxDecoration get subtle => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      );

  // ====================
  // Interactive Card Styles
  // ====================
  /// Elevated card with hover effect - for interactive content
  static BoxDecoration elevatedWithHover(bool isHovered) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(
              alpha: isHovered ? 0.3 : 0.2,
            ),
            blurRadius: isHovered ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// Filled card with hover effect - for interactive content
  static BoxDecoration filledWithHover(bool isHovered) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHovered ? AppColors.primary : AppColors.divider,
          width: isHovered ? 1.5 : 1,
        ),
      );

  // ====================
  // Themed Card Styles
  // ====================
  /// Card style for success/positive states
  static BoxDecoration get success => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
      color: AppColors.primary.withValues(alpha: 0.5),
      width: 1,
    ),
  );

  /// Card style for warning/caution states
  static BoxDecoration get warning => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.5),
          width: 1,
        ),
      );

  /// Card style for error/destructive states
  static BoxDecoration get error => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
          width: 1,
        ),
      );

  /// Card style for info/primary states
  static BoxDecoration get info => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      );

  // ====================
  // Compact Card Styles
  // ====================
  /// Compact filled card - smaller border radius for dense layouts
  static BoxDecoration get compactFilled => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      );

  /// Compact outlined card - smaller border radius for dense layouts
  static BoxDecoration get compactOutlined => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      );

  // ====================
  // Custom Card Factory
  // ====================
  /// Create a custom card style with custom colors and radius
  static BoxDecoration custom({
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 1,
    double borderRadius = 12,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: shadows,
      );
}
