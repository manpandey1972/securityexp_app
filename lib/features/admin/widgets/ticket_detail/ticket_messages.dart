import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/admin/data/models/internal_note.dart';

/// Message bubble for conversation display
class MessageBubble extends StatelessWidget {
  final SupportMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isFromSupport = message.isFromSupport;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isFromSupport ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromSupport) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: const Icon(Icons.person, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFromSupport ? AppColors.messageBubble : AppColors.surface,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isFromSupport ? null : const Radius.circular(4),
                  bottomRight: isFromSupport ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isFromSupport)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message.senderName,
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message.content,
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Attachments
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MessageAttachmentsWidget(attachments: message.attachments),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromSupport) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: const Icon(
                Icons.support_agent,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }
}

/// Internal note card for support staff
class InternalNoteCard extends StatelessWidget {
  final InternalNote note;

  const InternalNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  note.authorName,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(note.createdAt),
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple attachments widget - wrapper for MessageAttachments
class _MessageAttachmentsWidget extends StatelessWidget {
  final List<TicketAttachment> attachments;

  const _MessageAttachmentsWidget({required this.attachments});

  @override
  Widget build(BuildContext context) {
    // Import and use MessageAttachments from ticket_attachments.dart
    return const SizedBox(); // Placeholder - actual implementation uses MessageAttachments
  }
}
