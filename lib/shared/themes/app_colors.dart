import 'package:flutter/material.dart';

/// Minimal color palette for Security Experts app (15 unique colors).
///
/// USAGE GUIDELINES:
/// - Use `.withValues(alpha: ...)` for transparency variants instead of separate constants
/// - Use semantic names based on purpose, not visual appearance
/// - For overlays: `AppColors.black.withValues(alpha: 0.5)` not separate overlay constants
class AppColors {
  AppColors._();

  // ============================================================
  // BRAND COLORS (4)
  // ============================================================
  /// Primary green - main actions, buttons, CTAs, success states
  static const Color primary = Color(0xFF22C55E);

  /// Primary light - hover states, focus rings, accents
  static const Color primaryLight = Color(0xFF4ADE80);

  /// Error - destructive actions, validation errors, file icons (PDF)
  static const Color error = Color(0xFFC0392B);

  /// Warm accent - secondary brand color, earth tone
  static const Color warmAccent = Color(0xFFCCA48A);

  // ============================================================
  // BACKGROUND & SURFACE (3)
  // ============================================================
  /// Main app background - darkest layer
  static const Color background = Color(0xFF101518);

  /// Surface - cards, dialogs, elevated containers
  static const Color surface = Color(0xFF2C3034);

  /// Surface variant - borders, dividers, subtle backgrounds
  static const Color surfaceVariant = Color(0xFF44484A);

  // ============================================================
  // TEXT (2) - textPrimary is alias for white
  // ============================================================
  /// Secondary text - subtitles, descriptions
  static const Color textSecondary = Color(0xFF9EA5A2);

  /// Muted text - hints, disabled, placeholders
  static const Color textMuted = Color(0xFF7F8480);

  // ============================================================
  // SEMANTIC COLORS (3) - success=primary, teal=info
  // ============================================================
  /// Warning - attention, pending, stars/ratings (amber)
  static const Color warning = Color(0xFFFFC107);

  /// Info - information, help, links, payments (blue)
  static const Color info = Color(0xFF2196F3);

  /// Purple - in progress, special status
  static const Color purple = Color(0xFF9C27B0);

  // ============================================================
  // SPECIAL PURPOSE (1) - tagBackground=messageBubble, filePdf=error
  // ============================================================
  /// Message bubble - sent messages, tags, green accents
  static const Color messageBubble = Color(0xFF0B3B2E);

  // ============================================================
  // BASE (2)
  // ============================================================
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ============================================================
  // SEMANTIC ALIASES (backward compatibility)
  // ============================================================
  /// Primary text (alias for white)
  static const Color textPrimary = white;

  /// Success state (alias for primary green)
  static const Color success = primary;

  /// PDF/document icon color (alias for error red)
  static const Color filePdf = error;

  /// Tag background (alias for messageBubble)
  static const Color tagBackground = messageBubble;

  /// Teal/payments (alias for info blue)
  static const Color teal = info;

  /// Divider color (alias for surfaceVariant)
  static const Color divider = surfaceVariant;

  /// Rating star color (alias for warning/amber)
  static const Color ratingStar = warning;

  /// Orange status (alias for warning)
  static const Color orange = warning;

  /// Neutral/grey for closed/inactive states
  static const Color neutral = textMuted;

  // ============================================================
  // HELPER METHODS (use instead of separate overlay constants)
  // ============================================================
  /// Get black with specified opacity (0.0 - 1.0)
  static Color blackWithOpacity(double opacity) => black.withValues(alpha: opacity);

  /// Get white with specified opacity (0.0 - 1.0)
  static Color whiteWithOpacity(double opacity) => white.withValues(alpha: opacity);

  /// Get primary with specified opacity
  static Color primaryWithOpacity(double opacity) => primary.withValues(alpha: opacity);

  /// Get warning (amber) with specified opacity - useful for ratings
  static Color warningWithOpacity(double opacity) => warning.withValues(alpha: opacity);

  // ============================================================
  // COMMON OPACITY SHORTCUTS (backward compatibility)
  // ============================================================
  /// 50% black overlay - modals, scrims
  static Color get overlay50 => black.withValues(alpha: 0.5);

  /// 30% black overlay - subtle shadows
  static Color get overlay30 => black.withValues(alpha: 0.3);

  /// 30% white overlay - glass effects
  static Color get overlayWhite30 => white.withValues(alpha: 0.3);

  // ============================================================
  // ColorScheme (Material 3)
  // ============================================================
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: white,
    primaryContainer: primaryLight,
    onPrimaryContainer: white,
    secondary: warmAccent,
    onSecondary: background,
    secondaryContainer: warmAccent,
    onSecondaryContainer: background,
    tertiary: info,
    onTertiary: background,
    tertiaryContainer: info,
    onTertiaryContainer: background,
    error: error,
    onError: white,
    errorContainer: error,
    onErrorContainer: white,
    surface: surface,
    onSurface: white,
    surfaceContainerHighest: surfaceVariant,
    onSurfaceVariant: textSecondary,
    outline: surfaceVariant,
    outlineVariant: surface,
    shadow: surface,
    scrim: black,
    inverseSurface: white,
    onInverseSurface: background,
    inversePrimary: primary,
    surfaceTint: primary,
  );
}
