import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// A compact stat card for use in admin list pages.
///
/// Displays a value and label in a compact colored container.
/// Designed to be used inside a Row with Expanded wrapper.
class AdminCompactStatCard extends StatelessWidget {
  /// The label/title of the stat.
  final String label;

  /// The value to display (typically a number).
  final String value;

  /// Color used for text and background tint.
  final Color color;

  /// Whether to wrap in Expanded widget.
  /// Default is true for use in Row layouts.
  final bool expanded;

  const AdminCompactStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.bodyEmphasis.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.captionSmall.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );

    return expanded ? Expanded(child: card) : card;
  }
}
