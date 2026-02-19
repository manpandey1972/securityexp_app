import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';

/// Badge displaying ticket status with color coding
class StatusBadge extends StatelessWidget {
  final TicketStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, label) = _getStatusStyle();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.captionSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color, String) _getStatusStyle() {
    switch (status) {
      case TicketStatus.open:
        return (
          AppColors.warning.withValues(alpha: 0.2),
          AppColors.warning,
          'Open'
        );
      case TicketStatus.inProgress:
        return (
          AppColors.info.withValues(alpha: 0.2),
          AppColors.info,
          'In Progress'
        );
      case TicketStatus.inReview:
        return (
          AppColors.info.withValues(alpha: 0.2),
          AppColors.info,
          'In Review'
        );
      case TicketStatus.resolved:
        return (
          AppColors.primary.withValues(alpha: 0.2),
          AppColors.primary,
          'Resolved'
        );
      case TicketStatus.closed:
        return (
          AppColors.textMuted.withValues(alpha: 0.2),
          AppColors.textMuted,
          'Closed'
        );
    }
  }
}

/// Badge displaying ticket priority with color coding
class PriorityBadge extends StatelessWidget {
  final TicketPriority priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, label) = _getPriorityStyle();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.captionSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color, String) _getPriorityStyle() {
    switch (priority) {
      case TicketPriority.low:
        return (
          AppColors.textMuted.withValues(alpha: 0.2),
          AppColors.textMuted,
          'Low'
        );
      case TicketPriority.medium:
        return (
          AppColors.info.withValues(alpha: 0.2),
          AppColors.info,
          'Medium'
        );
      case TicketPriority.high:
        return (
          AppColors.warning.withValues(alpha: 0.2),
          AppColors.warning,
          'High'
        );
      case TicketPriority.critical:
        return (
          AppColors.error.withValues(alpha: 0.2),
          AppColors.error,
          'Urgent'
        );
    }
  }
}

/// Helper functions for status/priority UI
class TicketUIHelpers {
  static IconData getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return Icons.inbox;
      case TicketStatus.inProgress:
        return Icons.pending_actions;
      case TicketStatus.inReview:
        return Icons.rate_review;
      case TicketStatus.resolved:
        return Icons.check_circle;
      case TicketStatus.closed:
        return Icons.archive;
    }
  }

  static Color getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return AppColors.warning;
      case TicketStatus.inProgress:
      case TicketStatus.inReview:
        return AppColors.info;
      case TicketStatus.resolved:
        return AppColors.primary;
      case TicketStatus.closed:
        return AppColors.textMuted;
    }
  }

  static String getStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.inReview:
        return 'In Review';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  static Color getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return AppColors.textMuted;
      case TicketPriority.medium:
        return AppColors.info;
      case TicketPriority.high:
        return AppColors.warning;
      case TicketPriority.critical:
        return AppColors.error;
    }
  }

  static String getPriorityLabel(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.critical:
        return 'Urgent';
    }
  }
}
