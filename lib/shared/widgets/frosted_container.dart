import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';

/// A reusable frosted glass effect container widget.
///
/// This widget provides a consistent glassmorphism effect across the app
/// with customizable blur, opacity, and border radius.
///
/// Example usage:
/// ```dart
/// FrostedContainer(
///   borderRadius: 50,
///   child: Padding(
///     padding: EdgeInsets.all(12),
///     child: Text('Frosted content'),
///   ),
/// )
/// ```
class FrostedContainer extends StatelessWidget {
  /// The child widget to display inside the frosted container
  final Widget child;

  /// The border radius of the container (default: 24)
  final double borderRadius;

  /// Optional padding around the child widget
  final EdgeInsets? padding;

  /// The blur intensity (default: 15)
  final double blurSigma;

  /// The background opacity (default: 0.7)
  final double backgroundOpacity;

  /// Optional custom background color (defaults to AppColors.surface)
  final Color? backgroundColor;

  /// Whether to show the white border (default: true)
  final bool showBorder;

  /// Border width (default: 1.5)
  final double borderWidth;

  /// Whether to show shadow (default: true)
  final bool showShadow;

  const FrostedContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.blurSigma = 15,
    this.backgroundOpacity = 0.7,
    this.backgroundColor,
    this.showBorder = true,
    this.borderWidth = 1.5,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = backgroundColor ?? AppColors.surface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                baseColor.withValues(alpha: backgroundOpacity),
                baseColor.withValues(alpha: backgroundOpacity - 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: showBorder
                ? Border.all(
                    color: AppColors.white.withValues(alpha: 0.3),
                    width: borderWidth,
                  )
                : null,
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
