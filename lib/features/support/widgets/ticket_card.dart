import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:intl/intl.dart';

import '../data/models/models.dart';
import 'ticket_status_chip.dart';

/// Card widget displaying a support ticket summary.
///
/// Shows ticket status, type, subject, category, and timestamp.
/// Used in the ticket list view.
class TicketCard extends StatelessWidget {
  /// The ticket to display.
  final SupportTicket ticket;

  /// Callback when card is tapped.
  final VoidCallback? onTap;

  /// Whether to show unread indicator.
  final bool showUnreadIndicator;

  const TicketCard({
    super.key,
    required this.ticket,
    this.onTap,
    this.showUnreadIndicator = true,
  });

  /// Whether to show rating prompt (resolved tickets without rating)
  bool get _showRatingPrompt =>
      ticket.status == TicketStatus.resolved &&
      ticket.userSatisfactionRating == null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: ticket.hasUnreadSupportMessages && showUnreadIndicator
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Type icon, subject, status
              Row(
                children: [
                  // Type icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getTypeIcon(),
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Subject and ticket number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: AppTypography.bodyRegular.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ticket.ticketNumber.isNotEmpty
                              ? '#${ticket.ticketNumber}'
                              : '#${ticket.id.substring(0, 8).toUpperCase()}',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status chip
                  TicketStatusChip(status: ticket.status),
                ],
              ),

              const SizedBox(height: 12),

              // Category and type row
              Row(
                children: [
                  _buildTag(
                    icon: _getCategoryIcon(),
                    label: ticket.category.displayName,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  _buildTag(
                    icon: _getTypeIcon(),
                    label: ticket.type.displayName,
                    color: _getTypeColor(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Footer: timestamp and unread indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timestamp
                  Text(
                    _formatTimestamp(ticket.lastActivityAt),
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),

                  // Rating prompt for resolved unrated tickets
                  if (_showRatingPrompt)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_outline,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Rate',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  // Unread indicator
                  else if (ticket.hasUnreadSupportMessages && showUnreadIndicator)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'New reply',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (ticket.type) {
      case TicketType.bug:
        return Icons.bug_report;
      case TicketType.featureRequest:
        return Icons.lightbulb_outline;
      case TicketType.feedback:
        return Icons.feedback_outlined;
      case TicketType.support:
        return Icons.help_outline;
      case TicketType.account:
        return Icons.person_outline;
      case TicketType.payment:
        return Icons.payment;
    }
  }

  Color _getTypeColor() {
    switch (ticket.type) {
      case TicketType.bug:
        return AppColors.error;
      case TicketType.featureRequest:
        return AppColors.ratingStar;
      case TicketType.feedback:
        return AppColors.primary;
      case TicketType.support:
        return AppColors.info;
      case TicketType.account:
        return AppColors.purple;
      case TicketType.payment:
        return AppColors.teal;
    }
  }

  IconData _getCategoryIcon() {
    // Use the icon property from the enum
    return ticket.category.icon;
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
