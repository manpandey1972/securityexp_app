import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/ticket_attachment.dart';

/// Widget to display and open ticket attachments.
///
/// Supports:
/// - Image preview with full-screen zoom
/// - PDF opening in external viewer
/// - Other file types with download link
class AttachmentViewer extends StatelessWidget {
  final TicketAttachment attachment;
  final bool showFileName;
  final double? maxWidth;
  final double? maxHeight;

  const AttachmentViewer({
    super.key,
    required this.attachment,
    this.showFileName = true,
    this.maxWidth,
    this.maxHeight,
  });

  bool get _isImage {
    final mimeType = attachment.mimeType.toLowerCase();
    return mimeType.startsWith('image/') ||
        ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
            .any((ext) => attachment.fileName.toLowerCase().endsWith(ext));
  }

  bool get _isPdf {
    return attachment.mimeType.toLowerCase() == 'application/pdf' ||
        attachment.fileName.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAttachment(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 200,
          maxHeight: maxHeight ?? 150,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isImage) {
      return _buildImagePreview();
    } else if (_isPdf) {
      return _buildPdfPreview();
    } else {
      return _buildGenericFilePreview();
    }
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: attachment.url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: AppColors.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, _, _) => _buildErrorPlaceholder(),
          ),
          // Zoom indicator
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.zoom_in,
                color: AppColors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.picture_as_pdf,
          color: AppColors.filePdf,
          size: 40,
        ),
        const SizedBox(height: 8),
        if (showFileName)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              attachment.fileName,
              style: AppTypography.captionSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          _formatFileSize(attachment.fileSize),
          style: AppTypography.captionTiny.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildGenericFilePreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getFileIcon(),
          color: AppColors.primary,
          size: 40,
        ),
        const SizedBox(height: 8),
        if (showFileName)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              attachment.fileName,
              style: AppTypography.captionSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          _formatFileSize(attachment.fileSize),
          style: AppTypography.captionTiny.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: AppColors.textMuted,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            'Failed to load',
            style: AppTypography.captionTiny.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = attachment.fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openAttachment(BuildContext context) async {
    if (_isImage) {
      _openImageFullscreen(context);
    } else {
      _openInBrowser();
    }
  }

  void _openImageFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(attachment: attachment),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(attachment.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Full-screen image viewer with zoom and pan.
class _FullScreenImageViewer extends StatelessWidget {
  final TicketAttachment attachment;

  const _FullScreenImageViewer({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          attachment.fileName,
          style: const TextStyle(color: AppColors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.white),
            onPressed: () => _downloadImage(),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: attachment.url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: CircularProgressIndicator(color: AppColors.white),
            ),
            errorWidget: (_, _, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: AppColors.white.withValues(alpha: 0.54), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: AppColors.white.withValues(alpha: 0.54)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadImage() async {
    final uri = Uri.parse(attachment.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Grid of attachment thumbnails.
class AttachmentGrid extends StatelessWidget {
  final List<TicketAttachment> attachments;
  final int crossAxisCount;
  final double spacing;

  const AttachmentGrid({
    super.key,
    required this.attachments,
    this.crossAxisCount = 3,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        return AttachmentViewer(
          attachment: attachments[index],
          showFileName: false,
        );
      },
    );
  }
}

/// Horizontal list of attachment chips.
class AttachmentChips extends StatelessWidget {
  final List<TicketAttachment> attachments;
  final double spacing;

  const AttachmentChips({
    super.key,
    required this.attachments,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: attachments.map((attachment) {
        return _AttachmentChip(attachment: attachment);
      }).toList(),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final TicketAttachment attachment;

  const _AttachmentChip({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAttachment(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIcon(),
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                attachment.fileName,
                style: AppTypography.captionSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    final mimeType = attachment.mimeType.toLowerCase();
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.attach_file;
  }

  Future<void> _openAttachment(BuildContext context) async {
    final mimeType = attachment.mimeType.toLowerCase();
    if (mimeType.startsWith('image/')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullScreenImageViewer(attachment: attachment),
        ),
      );
    } else {
      final uri = Uri.parse(attachment.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
