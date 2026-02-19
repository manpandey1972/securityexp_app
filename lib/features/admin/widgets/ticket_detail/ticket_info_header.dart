import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'ticket_badges.dart';
import 'ticket_attachments.dart';

/// Header widget displaying ticket information and description
class TicketInfoHeader extends StatelessWidget {
  final SupportTicket ticket;
  final bool isExpanded;
  final Function(bool) onExpansionChanged;
  final bool canExpand;

  const TicketInfoHeader({
    super.key,
    required this.ticket,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.canExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject
          Text(
            ticket.subject,
            style: AppTypography.bodyEmphasis.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Info row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.person_outline,
                label: ticket.userName ?? ticket.userEmail,
              ),
              _InfoChip(icon: Icons.category, label: ticket.category.name),
              _InfoChip(
                icon: Icons.calendar_today,
                label: DateFormat('MMM d, y').format(ticket.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status & Priority badges
          Row(
            children: [
              StatusBadge(status: ticket.status),
              const SizedBox(width: 8),
              PriorityBadge(priority: ticket.priority),
              if (ticket.assignedTo != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_ind, size: 14, color: AppColors.info),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Description
          const SizedBox(height: 12),
          _DescriptionSection(
            ticket: ticket,
            isExpanded: isExpanded,
            canExpand: canExpand,
            onExpansionChanged: onExpansionChanged,
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final SupportTicket ticket;
  final bool isExpanded;
  final bool canExpand;
  final Function(bool) onExpansionChanged;

  const _DescriptionSection({
    required this.ticket,
    required this.isExpanded,
    required this.canExpand,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: canExpand ? () => onExpansionChanged(!isExpanded) : null,
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: canExpand
                      ? AppColors.textMuted
                      : AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: canExpand
                      ? AppColors.textMuted
                      : AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Description',
                  style: AppTypography.captionSmall.copyWith(
                    color: canExpand
                        ? AppColors.textMuted
                        : AppColors.textMuted.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!canExpand)
                  Text(
                    '(Hidden)',
                    style: AppTypography.captionTiny.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            Text(
              ticket.description,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (ticket.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Attachments (${ticket.attachments.length})',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MessageAttachments(attachments: ticket.attachments),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
