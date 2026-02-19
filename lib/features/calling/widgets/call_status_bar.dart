import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/features/calling/widgets/call_duration_display.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';

/// Top status bar for video calls showing duration and quality indicator.
class CallStatusBar extends StatelessWidget {
  /// ValueListenable for call duration in seconds
  final ValueListenable<int> durationSeconds;

  /// Current call quality metrics
  final CallQualityStats? callQuality;

  /// Whether this is a video call (audio calls don't show status bar)
  final bool isVideoCall;

  const CallStatusBar({
    super.key,
    required this.durationSeconds,
    required this.isVideoCall,
    this.callQuality,
  });

  @override
  Widget build(BuildContext context) {
    // Audio calls don't show status bar (name/duration in center)
    if (!isVideoCall) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<int>(
      valueListenable: durationSeconds,
      builder: (ctx, duration, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CallDurationDisplay(durationSeconds: duration),
            const SizedBox(width: 12),
            _buildQualityIndicator(),
          ],
        );
      },
    );
  }

  Widget _buildQualityIndicator() {
    final quality = callQuality?.quality ?? CallQualityLevel.unknown;

    final (IconData icon, Color color) = switch (quality) {
      CallQualityLevel.excellent => (
        Icons.signal_cellular_4_bar,
        AppColors.primary,
      ),
      CallQualityLevel.good => (Icons.signal_cellular_alt, AppColors.primary),
      CallQualityLevel.fair => (
        Icons.signal_cellular_alt_2_bar,
        AppColors.warmAccent,
      ),
      CallQualityLevel.poor => (
        Icons.signal_cellular_alt_1_bar,
        AppColors.error,
      ),
      CallQualityLevel.unknown => (
        Icons.signal_cellular_null,
        AppColors.textSecondary,
      ),
    };

    return Icon(icon, color: color, size: 18);
  }
}
