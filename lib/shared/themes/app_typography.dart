import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';

/// Text styles and typography configuration for the Security Experts app dark theme.
class AppTypography {
  AppTypography._(); // Private constructor to prevent instantiation

  // ====================
  // TextTheme Configuration
  // ====================
  /// Complete TextTheme for consistent typography across the app
  static const TextTheme textTheme = TextTheme(
    // Title styles
    titleMedium: TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w400,
    ),

    // Body styles
    bodyMedium: TextStyle(
      color: AppColors.textSecondary,
    ),

    // Label/small text
    labelSmall: TextStyle(
      color: AppColors.textMuted,
    ),
  );

  // ====================
  // Common TextStyle Variants
  // ====================

  // Caption/Small Text Styles (10-12px)
  /// Tiny caption text for timestamps and minimal info
  static const TextStyle captionTiny = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  /// Small caption text
  static const TextStyle captionSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  /// Emphasized caption text (badges, labels)
  static const TextStyle captionEmphasis = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Body Text Styles (14-16px)
  /// Small body text for secondary information
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// Regular body text
  static const TextStyle bodyRegular = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  /// Emphasized body text (names, important info)
  static const TextStyle bodyEmphasis = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Secondary/muted body text
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Heading Styles (18-32px)
  /// Extra small heading for section titles
  static const TextStyle headingXSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Small heading for card headers and dialog titles
  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Medium heading text
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Large heading for hero text
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Extra large heading for special displays
  static const TextStyle headingXLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Button text style
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.background,
  );

  // ====================
  // Component-Specific Styles
  // ====================

  /// Message text in chat bubbles
  static const TextStyle messageText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  /// Timestamp in messages and lists (smallest readable size)
  static const TextStyle timestamp = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  /// Edited/read receipt indicators
  static const TextStyle messageIndicator = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.textMuted,
  );

  /// Subtitle/description text in lists and cards
  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// Badge/label text
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // ====================
  // Font Weight Constants
  // ====================
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;
  static const bold = FontWeight.w700;

  // ====================
  // Helper Methods
  // ====================

  /// Create a text style with a specific color
  static TextStyle withColor(TextStyle base, Color color) {
    return base.copyWith(color: color);
  }

  /// Create a text style with a specific font weight
  static TextStyle withWeight(TextStyle base, FontWeight weight) {
    return base.copyWith(fontWeight: weight);
  }
}
