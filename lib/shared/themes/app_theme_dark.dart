import 'package:flutter/material.dart';

// =====================
// Export Theme Components
// =====================
export 'app_colors.dart';
export 'app_typography.dart';
export 'app_spacing.dart';
export 'app_borders.dart';
export 'app_shadows.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_borders.dart';
import 'app_shape_config.dart';

/// Dark theme configuration for the Security Experts app.
/// This file orchestrates the complete Material 3 dark theme using component files.
class AppThemeDarkConfig {
  AppThemeDarkConfig._(); // Private constructor to prevent instantiation

  // ====================
  // Main Theme Data (Material 3)
  // ====================
  /// Complete dark theme for the app
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: AppColors.colorScheme,
    scaffoldBackgroundColor: AppColors.background,

    // Card Theme
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: AppColors.background.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: AppBorders.cardShape,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.6,
      space: 1,
    ),

    // Icons
    iconTheme: const IconThemeData(color: AppColors.white, size: 22),

    // Text
    textTheme: AppTypography.textTheme,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.textPrimary,
      unselectedItemColor: AppColors.textSecondary,
      selectedLabelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.normal),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      
      // Normal state
      border: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppColors.divider, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppColors.divider, width: 1),
      ),
      
      // Focused state
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      
      // Error state
      errorBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      
      // Text styling
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      errorStyle: const TextStyle(
        color: AppColors.error,
        fontSize: 12,
      ),
      
      // Icon styling
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return AppColors.primary;
        }
        if (states.contains(WidgetState.error)) {
          return AppColors.error;
        }
        return AppColors.textMuted;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return AppColors.primary;
        }
        if (states.contains(WidgetState.error)) {
          return AppColors.error;
        }
        return AppColors.textSecondary;
      }),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        shape: AppShapeConfig.buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primary.withValues(alpha: 0.15);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primary.withValues(alpha: 0.25);
          }
          if (states.contains(WidgetState.focused)) {
            return AppColors.primary.withValues(alpha: 0.10);
          }
          return null;
        }),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: AppShapeConfig.buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primary.withValues(alpha: 0.10);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primary.withValues(alpha: 0.20);
          }
          if (states.contains(WidgetState.focused)) {
            return AppColors.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: AppShapeConfig.buttonShape,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primary.withValues(alpha: 0.10);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primary.withValues(alpha: 0.15);
          }
          if (states.contains(WidgetState.focused)) {
            return AppColors.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
      ),
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.tagBackground,
      selectedColor: AppColors.primaryLight,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.normal),
      side: const BorderSide(color: AppColors.divider, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return AppColors.surfaceVariant;
      }),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.white),
      side: const BorderSide(color: AppColors.divider, width: 2),
    ),

    // FloatingActionButton Theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 4,
    ),

    // ProgressIndicator Theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.surfaceVariant,
    ),

    // SnackBar Theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.normal),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog Theme
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: AppColors.background.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    ),
  );
}
