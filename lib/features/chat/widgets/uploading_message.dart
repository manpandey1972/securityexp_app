import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';

/// Widget for displaying messages being uploaded
class UploadingMessageWidget extends StatelessWidget {
  final String filename;
  final MessageType type;
  final double progress;

  const UploadingMessageWidget({
    super.key,
    required this.filename,
    required this.type,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case MessageType.video:
        icon = Icons.videocam;
        break;
      case MessageType.audio:
        icon = Icons.audiotrack;
        break;
      case MessageType.doc:
        icon = _getDocumentIcon();
        break;
      case MessageType.image:
      default:
        icon = Icons.image;
        break;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: AppIconSizes.medium),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  filename,
                  style: AppTypography.badge.copyWith(color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploading ${(progress * 100).toStringAsFixed(0)}%',
                style: AppTypography.captionEmphasis.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get appropriate icon based on document file extension
  IconData _getDocumentIcon() {
    final extension = filename.split('.').last.toLowerCase();
    
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
}
