import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';

import '../data/models/models.dart';

/// Chip widget displaying ticket status with appropriate color.
class TicketStatusChip extends StatelessWidget {
  /// The ticket status to display.
  final TicketStatus status;

  /// Whether to show in compact mode.
  final bool compact;

  const TicketStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            status.displayName,
            style:
                (compact
                        ? AppTypography.captionTiny
                        : AppTypography.captionSmall)
                    .copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ],
      ),
    );
  }

  // All color methods removed: always use AppColors.background and AppColors.textPrimary
}
