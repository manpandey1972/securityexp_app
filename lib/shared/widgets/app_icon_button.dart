import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_button_sizes.dart';

/// Modern icon button component with Material Design 3 styling.
/// Provides consistent sizing, colors, and hover/press feedback across the app.
///
/// Variants:
/// - Primary: Green background with primary color
/// - Secondary: Surface background with text color
/// - Ghost: Transparent background with muted color
/// - Destructive: Red background for delete/cancel actions
class AppIconButton extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// Callback when button is pressed
  final VoidCallback onPressed;

  /// Size of the button (defaults to medium)
  final double size;

  /// Size of the icon (defaults to standard)
  final double iconSize;

  /// Tooltip text shown on hover
  final String? tooltip;

  /// Whether the button is enabled
  final bool isEnabled;

  /// Variant style of the button
  final AppIconButtonVariant variant;

  /// Background color (overrides variant)
  final Color? backgroundColor;

  /// Foreground color (overrides variant)
  final Color? foregroundColor;

  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.size = AppButtonSizes.iconButtonMedium,
    this.iconSize = AppButtonSizes.iconStandard,
    this.tooltip,
    this.isEnabled = true,
    this.variant = AppIconButtonVariant.secondary,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  }) : super();

  /// Primary variant - bright green for main actions
  factory AppIconButton.primary({
    required IconData icon,
    required VoidCallback onPressed,
    double size = AppButtonSizes.iconButtonMedium,
    double iconSize = AppButtonSizes.iconStandard,
    String? tooltip,
  }) {
    return AppIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tooltip: tooltip,
      variant: AppIconButtonVariant.primary,
    );
  }

  /// Secondary variant - surface background with text color
  factory AppIconButton.secondary({
    required IconData icon,
    required VoidCallback onPressed,
    double size = AppButtonSizes.iconButtonMedium,
    double iconSize = AppButtonSizes.iconStandard,
    String? tooltip,
  }) {
    return AppIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tooltip: tooltip,
      variant: AppIconButtonVariant.secondary,
    );
  }

  /// Ghost variant - transparent with hover effect
  factory AppIconButton.ghost({
    required IconData icon,
    required VoidCallback onPressed,
    double size = AppButtonSizes.iconButtonMedium,
    double iconSize = AppButtonSizes.iconStandard,
    String? tooltip,
  }) {
    return AppIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tooltip: tooltip,
      variant: AppIconButtonVariant.ghost,
    );
  }

  /// Destructive variant - red for delete/cancel actions
  factory AppIconButton.destructive({
    required IconData icon,
    required VoidCallback onPressed,
    double size = AppButtonSizes.iconButtonMedium,
    double iconSize = AppButtonSizes.iconStandard,
    String? tooltip,
  }) {
    return AppIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tooltip: tooltip,
      variant: AppIconButtonVariant.destructive,
    );
  }

  /// Custom variant - use custom colors
  factory AppIconButton.custom({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    double size = AppButtonSizes.iconButtonMedium,
    double iconSize = AppButtonSizes.iconStandard,
    String? tooltip,
  }) {
    return AppIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tooltip: tooltip,
      variant: AppIconButtonVariant.custom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }

  _IconButtonColors _getColors() {
    switch (variant) {
      case AppIconButtonVariant.primary:
        return _IconButtonColors(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          foregroundColor: AppColors.primary,
          hoverColor: AppColors.primary.withValues(alpha: 0.25),
          pressedColor: AppColors.primary.withValues(alpha: 0.35),
        );

      case AppIconButtonVariant.secondary:
        return _IconButtonColors(
          backgroundColor: AppColors.surface.withValues(alpha: 0.7),
          foregroundColor: AppColors.textPrimary,
          hoverColor: AppColors.surface.withValues(alpha: 0.9),
          pressedColor: AppColors.surfaceVariant.withValues(alpha: 0.8),
        );

      case AppIconButtonVariant.ghost:
        return _IconButtonColors(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textSecondary,
          hoverColor: AppColors.primary.withValues(alpha: 0.10),
          pressedColor: AppColors.primary.withValues(alpha: 0.15),
        );

      case AppIconButtonVariant.destructive:
        return _IconButtonColors(
          backgroundColor: AppColors.error.withValues(alpha: 0.15),
          foregroundColor: AppColors.error,
          hoverColor: AppColors.error.withValues(alpha: 0.25),
          pressedColor: AppColors.error.withValues(alpha: 0.35),
        );

      case AppIconButtonVariant.custom:
        return _IconButtonColors(
          backgroundColor: backgroundColor ?? AppColors.surface,
          foregroundColor: foregroundColor ?? AppColors.textPrimary,
          hoverColor: (foregroundColor ?? AppColors.textPrimary)
              .withValues(alpha: 0.1),
          pressedColor: (foregroundColor ?? AppColors.textPrimary)
              .withValues(alpha: 0.15),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Tooltip(
      message: tooltip ?? '',
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          onPressed: isEnabled ? onPressed : null,
          icon: Icon(icon, size: iconSize),
          style: IconButton.styleFrom(
            backgroundColor: colors.backgroundColor,
            foregroundColor: colors.foregroundColor,
            disabledBackgroundColor: AppColors.surfaceVariant
                .withValues(alpha: 0.5),
            disabledForegroundColor: AppColors.textMuted,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (!isEnabled) return null;
              if (states.contains(WidgetState.pressed)) {
                return colors.pressedColor;
              }
              if (states.contains(WidgetState.hovered)) {
                return colors.hoverColor;
              }
              return null;
            }),
          ),
        ),
      ),
    );
  }
}

/// Enum for icon button variants
enum AppIconButtonVariant {
  /// Green background - for primary/main actions
  primary,

  /// Surface background - standard action
  secondary,

  /// Transparent - minimal style
  ghost,

  /// Red background - for destructive actions
  destructive,

  /// Custom colors
  custom,
}

/// Internal class to hold icon button colors
class _IconButtonColors {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color hoverColor;
  final Color pressedColor;

  _IconButtonColors({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.hoverColor,
    required this.pressedColor,
  });
}
