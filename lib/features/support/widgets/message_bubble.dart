import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:greenhive_app/features/chat/utils/chat_navigation_helper.dart';

import '../data/models/models.dart';

/// Message bubble for ticket conversation.
///
/// Displays user or support messages with different styling.
class MessageBubble extends StatelessWidget {
  /// The message to display.
  final SupportMessage message;

  /// Whether this is the current user's message.
  final bool isCurrentUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    // Show ticket created and status update system messages as support messages
    if (message.isSystemMessage &&
        (message.systemMessageType == SystemMessageType.ticketCreated ||
         message.systemMessageType == SystemMessageType.statusChange)) {
      // Render as if from support
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          margin: const EdgeInsets.only(right: 48, top: 4, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message bubble (no icon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  message.content,
                  style: AppTypography.bodyRegular,
                ),
              ),
              // Timestamp
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: AppTypography.captionTiny.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Other system messages: keep system style
    if (message.isSystemMessage) {
      return _SystemMessageBubble(message: message);
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: EdgeInsets.only(
          left: isCurrentUser ? 48 : 0,
          right: isCurrentUser ? 0 : 48,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender name for support messages
            if (!isCurrentUser && message.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 12),
                child: Text(
                  message.senderName,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),

            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.messageBubble
                    : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  Text(
                    message.content,
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // Attachments
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    MessageAttachments(attachments: message.attachments),
                  ],
                ],
              ),
            ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: AppTypography.captionTiny.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (isCurrentUser && message.readAt != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all, size: 12, color: AppColors.primary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;

    if (isToday) {
      return DateFormat.jm().format(time);
    } else {
      return DateFormat.MMMd().add_jm().format(time);
    }
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final SupportMessage message;

  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getSystemIcon(), size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  message.content,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  IconData _getSystemIcon() {
    switch (message.systemMessageType) {
      case SystemMessageType.statusChange:
        return Icons.swap_horiz;
      case SystemMessageType.assignmentChange:
        return Icons.person_add_outlined;
      case SystemMessageType.autoResponse:
        return Icons.smart_toy_outlined;
      case SystemMessageType.ticketCreated:
        return Icons.add_circle_outline;
      case SystemMessageType.ticketResolved:
        return Icons.check_circle_outline;
      case SystemMessageType.ticketClosed:
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

class MessageAttachments extends StatelessWidget {
  final List<TicketAttachment> attachments;

  const MessageAttachments({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        if (attachment.isImage) {
          return _ImageAttachment(attachment: attachment);
        } else {
          return _FileAttachment(attachment: attachment);
        }
      }).toList(),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final TicketAttachment attachment;

  const _ImageAttachment({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImagePreview(context, attachment.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 150),
          child: CachedNetworkImage(
            imageUrl: attachment.url,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            memCacheHeight: 300,
            placeholder: (context, url) => Container(
              width: 150,
              height: 100,
              color: AppColors.surface,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 150,
              height: 100,
              color: AppColors.surface,
              child: const Center(
                child: Icon(Icons.broken_image, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    final navigationHelper = ChatNavigationHelper(context);
    navigationHelper.showImagePreview(url);
  }
}

class _FileAttachment extends StatelessWidget {
  final TicketAttachment attachment;

  const _FileAttachment({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(attachment.url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attachment.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: attachment.isPdf ? AppColors.filePdf : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.fileName,
                    style: AppTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    attachment.fileSizeFormatted,
                    style: AppTypography.captionTiny.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
