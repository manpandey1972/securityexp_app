import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/features/chat/utils/chat_navigation_helper.dart';

/// Widget displaying list of attachments
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
          return ImageAttachment(attachment: attachment);
        } else {
          return FileAttachment(attachment: attachment);
        }
      }).toList(),
    );
  }
}

/// Image attachment with preview capability
class ImageAttachment extends StatelessWidget {
  final TicketAttachment attachment;

  const ImageAttachment({super.key, required this.attachment});

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

/// File attachment with download capability
class FileAttachment extends StatelessWidget {
  final TicketAttachment attachment;

  const FileAttachment({super.key, required this.attachment});

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
            const Icon(Icons.download, size: 18, color: AppColors.primary),
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
