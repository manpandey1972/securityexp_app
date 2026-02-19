import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';

/// A customizable drag handle widget commonly used in bottom sheets and draggable panels.
///
/// Provides visual feedback for draggable surfaces with configurable appearance.
///
/// Usage:
/// ```dart
/// DragHandle() // Default appearance
/// DragHandle(width: 50, height: 5, color: AppColors.primary)
/// DragHandle.small() // Factory for small handles
/// DragHandle.large() // Factory for large handles
/// ```
class DragHandle extends StatelessWidget {
  /// Width of the drag handle
  final double width;

  /// Height/thickness of the drag handle
  final double height;

  /// Color of the drag handle
  final Color color;

  /// Border radius of the drag handle
  final double borderRadius;

  /// Vertical margin around the drag handle
  final double verticalMargin;

  const DragHandle({
    super.key,
    this.width = 40,
    this.height = 4,
    this.color = AppColors.divider,
    this.borderRadius = 2,
    this.verticalMargin = 12,
  });

  /// Factory constructor for a small drag handle
  factory DragHandle.small({Key? key, Color color = AppColors.divider}) {
    return DragHandle(
      key: key,
      width: 32,
      height: 3,
      color: color,
      borderRadius: 1.5,
      verticalMargin: 8,
    );
  }

  /// Factory constructor for a large drag handle
  factory DragHandle.large({Key? key, Color color = AppColors.divider}) {
    return DragHandle(
      key: key,
      width: 48,
      height: 5,
      color: color,
      borderRadius: 2.5,
      verticalMargin: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalMargin),
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
