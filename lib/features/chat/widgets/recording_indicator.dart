import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';

/// Widget that shows recording duration during audio recording
class RecordingIndicator extends StatelessWidget {
  final Duration duration;
  final VoidCallback onStop;

  const RecordingIndicator({
    super.key,
    required this.duration,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.error,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onStop,
            child: const Icon(Icons.stop, color: AppColors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
