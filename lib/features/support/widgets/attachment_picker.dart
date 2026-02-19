import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:path/path.dart' as p;

import '../data/models/models.dart';

/// Widget for picking and displaying attachments.
///
/// Shows selected files with preview and allows adding/removing attachments.
class AttachmentPicker extends StatelessWidget {
  /// List of selected attachments.
  final List<PendingAttachment> attachments;

  /// Callback when image gallery is requested.
  final VoidCallback onPickImage;

  /// Callback when camera is requested.
  final VoidCallback onTakePhoto;

  /// Callback when file picker is requested.
  final VoidCallback onPickFile;

  /// Callback when attachment is removed.
  final ValueChanged<int> onRemove;

  /// Maximum number of attachments allowed.
  final int maxAttachments;

  const AttachmentPicker({
    super.key,
    required this.attachments,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onPickFile,
    required this.onRemove,
    this.maxAttachments = 5,
  });

  bool get canAddMore => attachments.length < maxAttachments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments',
              style: AppTypography.bodyRegular.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${attachments.length}/$maxAttachments',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Attachment list
        if (attachments.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attachments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _AttachmentItem(
                attachment: attachments[index],
                onRemove: () => onRemove(index),
              );
            },
          ),
          const SizedBox(height: 12),
        ],

        // Add attachment buttons
        if (canAddMore)
          Row(
            children: [
              _AddButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onPickImage,
              ),
              const SizedBox(width: 8),
              _AddButton(
                icon: Icons.attach_file,
                label: 'File',
                onTap: onPickFile,
              ),
            ],
          ),

        // Help text
        const SizedBox(height: 8),
        Text(
          'Max 10MB per file • Images, PDF, or text files',
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  final PendingAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentItem({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final fileName = attachment.filename;
    final extension = p.extension(fileName).toLowerCase();
    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
    ].contains(extension);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Preview or icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? _buildImagePreview(extension)
                : _buildFileIcon(extension),
          ),
          const SizedBox(width: 12),

          // File name and size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(attachment.bytes?.length ?? 0),
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            color: AppColors.textMuted,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String extension) {
    // On web or when bytes are available, use Image.memory
    if (attachment.bytes != null) {
      return Image.memory(
        attachment.bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFileIcon(extension),
      );
    }
    return _buildFileIcon(extension);
  }

  Widget _buildFileIcon(String extension) {
    IconData icon;
    Color color;

    switch (extension) {
      case '.pdf':
        icon = Icons.picture_as_pdf;
        color = AppColors.filePdf;
        break;
      case '.txt':
        icon = Icons.description;
        color = AppColors.info;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = AppColors.textMuted;
    }

    return Center(child: Icon(icon, color: color, size: 24));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
