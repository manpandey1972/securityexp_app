import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_spacing.dart';
import 'app_theme.dart';
import 'app_shape_config.dart';

/// Dark theme configuration for the Greenhive app.
///
/// This file contains the complete ThemeData for dark mode,
/// including all component themes (buttons, cards, inputs, etc.).
class DarkTheme {
  DarkTheme._();

  // Dark mode specific colors
  static const Color _surfaceDark = Color(0xFF121212);
  static const Color _surfaceContainerDark = Color(0xFF1E1E1E);
  static const Color _surfaceContainerHighDark = Color(0xFF2A2A2A);
  static const Color _borderDark = Color(0xFF3A3A3A);

  /// Build the complete dark theme
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: _surfaceDark,
      textTheme: _textTheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      cardTheme: _cardTheme,
      inputDecorationTheme: _inputDecorationTheme,
      bottomNavigationBarTheme: _bottomNavigationBarTheme,
    );
  }

  // ========== COLOR SCHEME ==========
  static ColorScheme get _colorScheme {
    return ColorScheme.dark(
      primary: AppTheme.lightGreen,
      secondary: AppTheme.accentLightGold,
      tertiary: AppTheme.primaryGreen,
      error: AppTheme.errorRed,
      surface: _surfaceContainerDark,
      surfaceDim: _surfaceDark,
      outline: AppTheme.mediumGray,
      outlineVariant: AppTheme.lightGray,
    );
  }

  // ========== TEXT THEME ==========
  static TextTheme get _textTheme {
    return GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppTheme.white,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppTheme.white,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.white,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppTheme.lightGray,
        height: 1.5,
      ),
    );
  }

  // ========== APP BAR ==========
  static AppBarTheme get _appBarTheme {
    return AppBarTheme(
      backgroundColor: _surfaceContainerDark,
      foregroundColor: AppTheme.white,
      elevation: AppTheme.elevation0,
      centerTitle: true,
      scrolledUnderElevation: AppTheme.elevation4,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme.white,
      ),
      iconTheme: const IconThemeData(color: AppTheme.white, size: 24),
      actionsIconTheme: const IconThemeData(color: AppTheme.white, size: 24),
    );
  }

  // ========== ELEVATED BUTTON ==========
  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.lightGreen,
        foregroundColor: AppTheme.darkGray,
        elevation: AppTheme.elevation4,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing24,
          vertical: AppSpacing.spacing12,
        ),
        shape: AppShapeConfig.buttonShape,
      ),
    );
  }

  // ========== OUTLINED BUTTON ==========
  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.lightGreen,
        backgroundColor: Colors.transparent,
        elevation: AppTheme.elevation0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing24,
          vertical: AppSpacing.spacing12,
        ),
        shape: AppShapeConfig.buttonShape,
        side: const BorderSide(color: AppTheme.lightGreen, width: 2),
      ),
    );
  }

  // ========== CARD ==========
  static CardThemeData get _cardTheme {
    return CardThemeData(
      color: _surfaceContainerHighDark,
      elevation: AppTheme.elevation2,
      shadowColor: AppTheme.darkGray.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
    );
  }

  // ========== INPUT DECORATION ==========
  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: _surfaceContainerHighDark,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing16,
        vertical: AppSpacing.spacing12,
      ),
      border: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: _borderDark, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: _borderDark, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppTheme.lightGreen, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.mediumGray,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.mediumGray,
      ),
      prefixIconColor: AppTheme.mediumGray,
      suffixIconColor: AppTheme.mediumGray,
    );
  }

  // ========== BOTTOM NAVIGATION BAR ==========
  static BottomNavigationBarThemeData get _bottomNavigationBarTheme {
    return BottomNavigationBarThemeData(
      backgroundColor: _surfaceContainerDark,
      selectedItemColor: AppTheme.lightGreen,
      unselectedItemColor: AppTheme.mediumGray,
      elevation: AppTheme.elevation8,
      selectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
    );
  }
}
