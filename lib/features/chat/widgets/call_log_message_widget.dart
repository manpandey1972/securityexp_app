import 'package:flutter/material.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/features/chat/utils/chat_utils.dart';

/// Widget that displays a call log message (missed, rejected, ended)
class CallLogMessageWidget extends StatelessWidget {
  final Message message;
  final bool fromMe;

  const CallLogMessageWidget({
    super.key,
    required this.message,
    required this.fromMe,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final isVideo = metadata['isVideo'] == true;
    final status = metadata['status'] as String? ?? 'ended';
    final duration = metadata['duration'] as int? ?? 0;

    // Determine icon and text
    IconData icon;
    String text;
    Color iconColor;

    if (status == 'missed' || status == 'rejected' || status == 'cancelled') {
      icon = isVideo ? Icons.videocam_off : Icons.phone_missed;
      text = 'Missed ${isVideo ? 'video' : 'voice'} call';
      iconColor = AppColors.error;
    } else {
      // Ended normally
      icon = isVideo ? Icons.videocam : Icons.phone;
      text = '${isVideo ? 'Video' : 'Voice'} call';
      if (duration > 0) {
        text += ' • ${DateTimeFormatter.formatCallDuration(duration)}';
      }
      iconColor = AppColors.textPrimary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: fromMe ? AppColors.messageBubble : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 0.5),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  text,
                  style: AppTypography.messageText.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.medium,
                  ),
                ),
                Text(
                  DateTimeFormatter.formatTimeOnly(message.timestamp.toDate()),
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
