import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';

/// Widget for displaying document attachments in chat messages.
///
/// Supports PDF and text files with download progress indicator
/// and tap to open in-app viewer.
class DocumentMessageBubble extends StatelessWidget {
  final String fileName;
  final String? fileSize;
  final String? mimeType;
  final String? mediaUrl;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool fromMe;

  const DocumentMessageBubble({
    super.key,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.mediaUrl,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.onTap,
    this.onDownload,
    this.fromMe = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fromMe ? AppColors.messageBubble : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isDownloading
                  ? _buildDownloadProgress()
                  : Icon(
                      _getFileIcon(),
                      color: _getIconColor(),
                      size: AppIconSizes.large,
                    ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getFileTypeLabel(),
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (fileSize != null) ...[
                        Text(
                          ' • ',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          fileSize!,
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Download/open indicator
            if (onDownload != null && !isDownloading)
              IconButton(
                onPressed: onDownload,
                icon: const Icon(
                  Icons.download_rounded,
                  color: AppColors.textSecondary,
                  size: AppIconSizes.medium,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            value: downloadProgress > 0 ? downloadProgress : null,
            strokeWidth: 2.5,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(_getIconColor()),
          ),
        ),
        Text(
          '${(downloadProgress * 100).toInt()}%',
          style: AppTypography.captionTiny.copyWith(
            color: _getIconColor(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon() {
    final extension = _getFileExtension().toLowerCase();
    
    if (extension == 'pdf') {
      return Icons.picture_as_pdf_rounded;
    } else if (['txt', 'md', 'log'].contains(extension)) {
      return Icons.description_rounded;
    } else if (['dart', 'js', 'ts', 'json', 'xml', 'yaml', 'yml', 'html', 'css'].contains(extension)) {
      return Icons.code_rounded;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.article_rounded;
    } else if (['xls', 'xlsx'].contains(extension)) {
      return Icons.table_chart_rounded;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow_rounded;
    }
    
    return Icons.insert_drive_file_rounded;
  }

  Color _getIconColor() {
    return AppColors.textPrimary;
  }

  Color _getIconBackgroundColor() {
    return AppColors.textPrimary.withValues(alpha: 0.15);
  }

  String _getFileExtension() {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  String _getFileTypeLabel() {
    final extension = _getFileExtension().toLowerCase();
    
    if (extension == 'pdf') return 'PDF';
    if (['txt', 'md', 'log'].contains(extension)) return 'Text';
    if (['dart', 'js', 'ts', 'json', 'xml', 'yaml', 'yml', 'html', 'css'].contains(extension)) return 'Code';
    if (['doc', 'docx'].contains(extension)) return 'Word';
    if (['xls', 'xlsx'].contains(extension)) return 'Excel';
    if (['ppt', 'pptx'].contains(extension)) return 'PowerPoint';
    
    return extension.toUpperCase();
  }
}

/// Determines if a file can be viewed in-app
bool canViewInApp(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return ['pdf', 'txt', 'md', 'log', 'dart', 'js', 'ts', 'json', 'xml', 'yaml', 'yml', 'html', 'css'].contains(extension);
}

/// Determines if a file is a PDF
bool isPdfFile(String fileName) {
  return fileName.toLowerCase().endsWith('.pdf');
}

/// Determines if a file is a text/code file
bool isTextFile(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return ['txt', 'md', 'log', 'dart', 'js', 'ts', 'json', 'xml', 'yaml', 'yml', 'html', 'css'].contains(extension);
}
