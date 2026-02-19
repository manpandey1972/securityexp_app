import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

/// Displays current call status (connecting, active, ending, etc.)
/// Extracted from call_page.dart for better separation of concerns
class CallStatusDisplay extends StatelessWidget {
  final String status;
  final String displayName;
  final bool isConnected;
  final TextStyle? statusTextStyle;
  final TextStyle? nameTextStyle;

  const CallStatusDisplay({
    super.key,
    required this.status,
    required this.displayName,
    required this.isConnected,
    this.statusTextStyle,
    this.nameTextStyle,
  });

  /// Get user-friendly status message
  String _getStatusMessage() {
    switch (status.toLowerCase()) {
      case 'ringing':
      case 'pending':
        return 'Calling...';
      case 'connecting':
        return 'Connecting...';
      case 'connected':
      case 'active':
        return 'Connected';
      case 'ended':
      case 'completed':
        return 'Call ended';
      case 'cancelled':
      case 'missed':
        return 'Call cancelled';
      case 'rejected':
        return 'Call rejected';
      default:
        return status;
    }
  }


  @override
  Widget build(BuildContext context) {
    final statusMsg = _getStatusMessage();
    // Don't show "Connected" status as it's redundant during the call
    final showStatus = statusMsg != 'Connected';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display name
        Text(
          displayName,
          style:
              nameTextStyle ??
              AppTypography.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.bold,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showStatus) ...[
          const SizedBox(height: 8),
          // Status message
          Text(
            statusMsg,
            style:
                statusTextStyle ??
                AppTypography.messageText.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: AppTypography.medium,
                ),
          ),
        ],
      ],
    );
  }
}
