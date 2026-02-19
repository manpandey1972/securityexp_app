import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// Displays the call duration with formatted time (HH:MM:SS or MM:SS)
/// Extracted from call_page.dart for reusability
class CallDurationDisplay extends StatelessWidget {
  final int durationSeconds;
  final TextStyle? textStyle;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const CallDurationDisplay({
    super.key,
    required this.durationSeconds,
    this.textStyle,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// Format seconds into HH:MM:SS or MM:SS format
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatDuration(durationSeconds),
          style:
              textStyle ??
              AppTypography.messageText.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.medium,
              ),
        ),
      ],
    );
  }
}
