import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';

/// Interactive star rating input widget.
///
/// Allows users to select a rating from 1-5 stars by tapping.
/// Stars are filled from left to right up to the selected value.
///
/// Usage:
/// ```dart
/// StarRatingInput(
///   rating: _selectedRating,
///   onRatingChanged: (rating) => setState(() => _selectedRating = rating),
///   size: 40,
/// )
/// ```
class StarRatingInput extends StatelessWidget {
  /// Current rating value (1-5, or 0 for no selection)
  final int rating;

  /// Callback when rating changes
  final ValueChanged<int>? onRatingChanged;

  /// Size of each star icon
  final double size;

  /// Color of filled stars
  final Color activeColor;

  /// Color of unfilled stars
  final Color inactiveColor;

  /// Spacing between stars
  final double spacing;

  /// Whether the input is enabled
  final bool enabled;

  const StarRatingInput({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 40,
    this.activeColor = AppColors.warning, // Yellow/Gold
    this.inactiveColor = AppColors.textMuted,
    this.spacing = 8,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final isFilled = starNumber <= rating;

        return GestureDetector(
          onTap: enabled && onRatingChanged != null
              ? () => onRatingChanged!(starNumber)
              : null,
          child: Padding(
            padding: EdgeInsets.only(right: index < 4 ? spacing : 0),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: isFilled ? activeColor : inactiveColor,
            ),
          ),
        );
      }),
    );
  }
}

/// Display-only star rating widget.
///
/// Shows a rating value with filled/partial stars.
/// Use this for displaying existing ratings (not for input).
///
/// Usage:
/// ```dart
/// StarRatingDisplay(
///   rating: 4.5,
///   size: 16,
///   showValue: true,
/// )
/// ```
class StarRatingDisplay extends StatelessWidget {
  /// Rating value (0.0-5.0)
  final double rating;

  /// Size of each star icon
  final double size;

  /// Color of filled stars
  final Color activeColor;

  /// Color of unfilled stars
  final Color inactiveColor;

  /// Spacing between stars
  final double spacing;

  /// Whether to show the numeric value
  final bool showValue;

  /// Text style for the numeric value
  final TextStyle? valueTextStyle;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.activeColor = AppColors.warning,
    this.inactiveColor = AppColors.textMuted,
    this.spacing = 2,
    this.showValue = false,
    this.valueTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          final difference = rating - starNumber + 1;

          IconData icon;
          Color color;

          if (difference >= 1) {
            // Fully filled
            icon = Icons.star_rounded;
            color = activeColor;
          } else if (difference >= 0.5) {
            // Half filled
            icon = Icons.star_half_rounded;
            color = activeColor;
          } else {
            // Empty
            icon = Icons.star_outline_rounded;
            color = inactiveColor;
          }

          return Padding(
            padding: EdgeInsets.only(right: index < 4 ? spacing : 0),
            child: Icon(icon, size: size, color: color),
          );
        }),
        if (showValue) ...[
          SizedBox(width: spacing * 2),
          Text(
            rating.toStringAsFixed(1),
            style: valueTextStyle ??
                TextStyle(
                  fontSize: size * 0.9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ],
    );
  }
}
