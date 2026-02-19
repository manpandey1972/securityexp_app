import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';

/// A reusable card widget that follows the GreenHive design system.
///
/// Use this widget as the base for all card-like containers in the app
/// to ensure consistent styling across features.
///
/// Example:
/// ```dart
/// AppCard(
///   child: Text('Card content'),
/// )
///
/// // With tap handler
/// AppCard(
///   onTap: () => print('tapped'),
///   child: Text('Tappable card'),
/// )
///
/// // With custom padding
/// AppCard(
///   padding: EdgeInsets.all(AppSpacing.spacing24),
///   child: Text('Custom padding'),
/// )
/// ```
class AppCard extends StatelessWidget {
  /// The content of the card.
  final Widget child;

  /// Optional callback when the card is tapped.
  final VoidCallback? onTap;

  /// Optional callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Padding inside the card. Defaults to 16px on all sides.
  final EdgeInsetsGeometry? padding;

  /// Margin outside the card. Defaults to no margin.
  final EdgeInsetsGeometry? margin;

  /// Background color of the card. Defaults to [AppColors.surface].
  final Color? backgroundColor;

  /// Border color. Defaults to no border.
  final Color? borderColor;

  /// Border width when [borderColor] is set. Defaults to 1.
  final double borderWidth;

  /// Border radius. Defaults to [AppBorders.radius12].
  final double? borderRadius;

  /// Elevation/shadow. Defaults to 0 (flat card).
  final double elevation;

  /// Whether to clip the content. Defaults to true.
  final bool clipBehavior;

  /// Creates an AppCard widget.
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.elevation = 0,
    this.clipBehavior = true,
  });

  /// Creates an AppCard with elevated styling (subtle shadow).
  factory AppCard.elevated({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? borderRadius,
  }) {
    return AppCard(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor ?? AppColors.surfaceVariant,
      borderRadius: borderRadius,
      elevation: 2,
      child: child,
    );
  }

  /// Creates an AppCard with outlined styling (border, no fill).
  factory AppCard.outlined({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? borderColor,
    double? borderRadius,
  }) {
    return AppCard(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: padding,
      margin: margin,
      backgroundColor: Colors.transparent,
      borderColor: borderColor ?? AppColors.divider,
      borderRadius: borderRadius,
      child: child,
    );
  }

  /// Creates an AppCard with highlighted styling (primary border).
  factory AppCard.highlighted({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? borderRadius,
  }) {
    return AppCard(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: padding,
      margin: margin,
      backgroundColor: AppColors.surface,
      borderColor: AppColors.primary,
      borderWidth: 1.5,
      borderRadius: borderRadius,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppBorders.radius12;
    final effectiveBackgroundColor = backgroundColor ?? AppColors.surface;
    final effectivePadding = padding ?? const EdgeInsets.all(AppSpacing.spacing16);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: AppColors.surface.withValues(alpha: 0.3),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: effectivePadding,
        child: child,
      ),
    );

    if (clipBehavior) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        child: card,
      );
    }

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// A card specifically designed for list items.
///
/// Includes standard margin and can optionally show unread indicator.
class AppListCard extends StatelessWidget {
  /// The content of the card.
  final Widget child;

  /// Optional callback when the card is tapped.
  final VoidCallback? onTap;

  /// Whether to show unread/highlight indicator.
  final bool showHighlight;

  /// Padding inside the card.
  final EdgeInsetsGeometry? padding;

  const AppListCard({
    super.key,
    required this.child,
    this.onTap,
    this.showHighlight = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing16,
        vertical: AppSpacing.spacing4,
      ),
      padding: padding,
      borderColor: showHighlight ? AppColors.primary : null,
      borderWidth: showHighlight ? 1.5 : 1.0,
      child: child,
    );
  }
}
