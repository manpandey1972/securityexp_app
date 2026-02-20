import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_spacing.dart';
import 'app_theme.dart';
import 'app_shape_config.dart';

/// Light theme configuration for the Security Experts app.
///
/// This file contains the complete ThemeData for light mode,
/// including all component themes (buttons, cards, inputs, etc.).
class LightTheme {
  LightTheme._();

  /// Build the complete light theme
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppTheme.veryLightGray,
      textTheme: _textTheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      cardTheme: _cardTheme,
      inputDecorationTheme: _inputDecorationTheme,
      checkboxTheme: _checkboxTheme,
      switchTheme: _switchTheme,
      chipTheme: _chipTheme,
      progressIndicatorTheme: _progressIndicatorTheme,
      floatingActionButtonTheme: _floatingActionButtonTheme,
      snackBarTheme: _snackBarTheme,
      bottomNavigationBarTheme: _bottomNavigationBarTheme,
      dialogTheme: _dialogTheme,
      dividerTheme: _dividerTheme,
      listTileTheme: _listTileTheme,
      tabBarTheme: _tabBarTheme,
    );
  }

  // ========== COLOR SCHEME ==========
  static const ColorScheme _colorScheme = ColorScheme.light(
    primary: AppTheme.primaryGreen,
    secondary: AppTheme.accentGold,
    tertiary: AppTheme.lightGreen,
    error: AppTheme.errorRed,
    surface: AppTheme.white,
    surfaceBright: AppTheme.veryLightGray,
    outline: AppTheme.lightGray,
    outlineVariant: AppTheme.mediumGray,
  );

  // ========== TEXT THEME ==========
  static TextTheme get _textTheme {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppTheme.darkGray,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppTheme.darkGray,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGray,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGray,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGray,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGray,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppTheme.darkGray,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.darkGray,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppTheme.darkGray,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.darkGray,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme.mediumGray,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.white,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.mediumGray,
        letterSpacing: 0.4,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppTheme.mediumGray,
        letterSpacing: 0.5,
      ),
    );
  }

  // ========== APP BAR ==========
  static AppBarTheme get _appBarTheme {
    return AppBarTheme(
      backgroundColor: AppTheme.primaryGreen,
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
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        elevation: AppTheme.elevation4,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing24,
          vertical: AppSpacing.spacing12,
        ),
        shape: AppShapeConfig.buttonShape,
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.white,
        ),
      ),
    );
  }

  // ========== OUTLINED BUTTON ==========
  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryGreen,
        backgroundColor: Colors.transparent,
        elevation: AppTheme.elevation0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing24,
          vertical: AppSpacing.spacing12,
        ),
        shape: AppShapeConfig.buttonShape,
        side: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  // ========== TEXT BUTTON ==========
  static TextButtonThemeData get _textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primaryGreen,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing16,
          vertical: AppSpacing.spacing8,
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ========== CARD ==========
  static CardThemeData get _cardTheme {
    return CardThemeData(
      color: AppTheme.white,
      elevation: AppTheme.elevation2,
      shadowColor: AppTheme.darkGray.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      margin: const EdgeInsets.all(AppSpacing.spacing8),
      clipBehavior: Clip.antiAlias,
    );
  }

  // ========== INPUT DECORATION ==========
  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppTheme.veryLightGray,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing16,
        vertical: AppSpacing.spacing12,
      ),
      border: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppTheme.lightGray, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppTheme.lightGray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppTheme.errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppShapeConfig.textFieldBorderRadius,
        borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
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
      errorStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.errorRed,
      ),
    );
  }

  // ========== CHECKBOX ==========
  static CheckboxThemeData get _checkboxTheme {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTheme.primaryGreen;
        }
        return Colors.transparent;
      }),
      side: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
    );
  }

  // ========== SWITCH ==========
  static SwitchThemeData get _switchTheme {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTheme.white;
        }
        return AppTheme.lightGray;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTheme.primaryGreen;
        }
        return AppTheme.lightGray;
      }),
    );
  }

  // ========== CHIP ==========
  static ChipThemeData get _chipTheme {
    return ChipThemeData(
      backgroundColor: AppTheme.veryLightGreen,
      disabledColor: AppTheme.lightGray,
      selectedColor: AppTheme.primaryGreen,
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.darkGray,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing12,
        vertical: AppSpacing.spacing8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius24),
      ),
      side: const BorderSide(color: Colors.transparent),
    );
  }

  // ========== PROGRESS INDICATOR ==========
  static const ProgressIndicatorThemeData _progressIndicatorTheme =
      ProgressIndicatorThemeData(
    color: AppTheme.primaryGreen,
    linearTrackColor: AppTheme.lightGray,
    circularTrackColor: AppTheme.lightGray,
  );

  // ========== FLOATING ACTION BUTTON ==========
  static FloatingActionButtonThemeData get _floatingActionButtonTheme {
    return FloatingActionButtonThemeData(
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: AppTheme.white,
      elevation: AppTheme.elevation8,
      focusElevation: AppTheme.elevation12,
      hoverElevation: AppTheme.elevation12,
      highlightElevation: AppTheme.elevation8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
    );
  }

  // ========== SNACKBAR ==========
  static SnackBarThemeData get _snackBarTheme {
    return SnackBarThemeData(
      backgroundColor: AppTheme.darkGray,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
    );
  }

  // ========== BOTTOM NAVIGATION BAR ==========
  static BottomNavigationBarThemeData get _bottomNavigationBarTheme {
    return BottomNavigationBarThemeData(
      backgroundColor: AppTheme.white,
      selectedItemColor: AppTheme.primaryGreen,
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

  // ========== DIALOG ==========
  static DialogThemeData get _dialogTheme {
    return DialogThemeData(
      backgroundColor: AppTheme.white,
      elevation: AppTheme.elevation8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkGray,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.darkGray,
      ),
    );
  }

  // ========== DIVIDER ==========
  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppTheme.lightGray,
    thickness: 1,
    space: AppSpacing.spacing16,
  );

  // ========== LIST TILE ==========
  static ListTileThemeData get _listTileTheme {
    return ListTileThemeData(
      textColor: AppTheme.darkGray,
      iconColor: AppTheme.primaryGreen,
      selectedTileColor: AppTheme.veryLightGreen,
      selectedColor: AppTheme.primaryGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
    );
  }

  // ========== TAB BAR ==========
  static TabBarThemeData get _tabBarTheme {
    return TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryGreen, width: 3),
        ),
      ),
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryGreen,
      ),
      unselectedLabelStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.mediumGray,
      ),
      labelColor: AppTheme.primaryGreen,
      unselectedLabelColor: AppTheme.mediumGray,
    );
  }
}
