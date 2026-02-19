import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:greenhive_app/shared/services/upload_manager.dart';
import 'package:greenhive_app/data/models/upload_state.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_borders.dart';
import 'package:greenhive_app/shared/themes/app_icon_sizes.dart';
import 'package:greenhive_app/shared/themes/app_spacing.dart';

/// Global upload progress indicator widget.
///
/// Shows a floating bottom bar when uploads are in progress.
/// Can be tapped to expand and show details of all uploads.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     MainContent(),
///     GlobalUploadIndicator(),
///   ],
/// )
/// ```
class GlobalUploadIndicator extends StatefulWidget {
  const GlobalUploadIndicator({super.key});

  @override
  State<GlobalUploadIndicator> createState() => _GlobalUploadIndicatorState();
}

class _GlobalUploadIndicatorState extends State<GlobalUploadIndicator>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadManager>(
      builder: (context, uploadManager, child) {
        final activeUploads = uploadManager.activeUploads;

        // Don't show if no active uploads
        if (activeUploads.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: Material(
            elevation: 8,
            borderRadius: AppBorders.borderRadiusMedium,
            color: AppColors.surface,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Collapsed header - always visible
                  _buildHeader(uploadManager, activeUploads),

                  // Expanded content - upload list
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    child: _buildExpandedContent(uploadManager),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    UploadManager uploadManager,
    List<UploadState> activeUploads,
  ) {
    final uploadCount = activeUploads.length;
    final totalProgress = uploadManager.totalProgress;

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: AppBorders.borderRadiusMedium,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Upload icon with badge
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppBorders.borderRadiusSmall,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.primary,
                    size: AppIconSizes.standard,
                  ),
                ),
                if (uploadCount > 1)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$uploadCount',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: AppSpacing.spacing12),

            // Upload info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uploadCount == 1
                        ? 'Uploading ${activeUploads.first.filename}'
                        : 'Uploading $uploadCount files',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppSpacing.spacing4),
                  // Progress bar
                  ClipRRect(
                    borderRadius: AppBorders.borderRadiusXSmall,
                    child: LinearProgressIndicator(
                      value: totalProgress,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(totalProgress * 100).toInt()}% complete',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Expand/collapse icon
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.keyboard_arrow_up,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(UploadManager uploadManager) {
    final uploads = uploadManager.uploads.values.toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: uploads.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final upload = uploads[index];
          return _UploadListItem(
            upload: upload,
            onCancel: upload.isActive
                ? () => uploadManager.cancelUpload(upload.id)
                : null,
            onRemove: !upload.isActive
                ? () => uploadManager.removeUpload(upload.id)
                : null,
          );
        },
      ),
    );
  }
}

/// Individual upload item in the expanded list
class _UploadListItem extends StatelessWidget {
  final UploadState upload;
  final VoidCallback? onCancel;
  final VoidCallback? onRemove;

  const _UploadListItem({required this.upload, this.onCancel, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // File type icon
          _buildTypeIcon(),
          SizedBox(width: AppSpacing.spacing12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload.filename,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _buildStatusRow(),
              ],
            ),
          ),

          // Action button
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (upload.type) {
      case MessageType.image:
        icon = Icons.image_outlined;
        color = AppColors.info;
        break;
      case MessageType.video:
        icon = Icons.videocam_outlined;
        color = AppColors.purple;
        break;
      case MessageType.audio:
        icon = Icons.audiotrack_outlined;
        color = AppColors.orange;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        color = AppColors.neutral;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppBorders.borderRadiusSmallAlt,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildStatusRow() {
    Color statusColor;
    String statusText;

    switch (upload.status) {
      case UploadStatus.uploading:
        statusColor = AppColors.primary;
        statusText = '${(upload.progress * 100).toInt()}%';
        break;
      case UploadStatus.completed:
        statusColor = AppColors.success;
        statusText = 'Completed';
        break;
      case UploadStatus.failed:
        statusColor = AppColors.error;
        statusText = 'Failed';
        break;
      case UploadStatus.cancelled:
        statusColor = AppColors.orange;
        statusText = 'Cancelled';
        break;
    }

    return Row(
      children: [
        if (upload.status == UploadStatus.uploading) ...[
          Expanded(
            child: ClipRRect(
              borderRadius: AppBorders.borderRadiusTiny,
              child: LinearProgressIndicator(
                value: upload.progress,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 3,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.spacing8),
        ],
        Text(
          statusText,
          style: AppTypography.captionSmall.copyWith(color: statusColor),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (upload.isActive && onCancel != null) {
      return IconButton(
        onPressed: onCancel,
        icon: const Icon(Icons.close, size: 18),
        color: AppColors.textSecondary,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: 'Cancel upload',
      );
    } else if (!upload.isActive && onRemove != null) {
      return IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.close, size: 18),
        color: AppColors.textSecondary,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: 'Dismiss',
      );
    }
    return const SizedBox(width: 32);
  }
}

/// Compact upload indicator for use in app bar or other tight spaces
class CompactUploadIndicator extends StatelessWidget {
  const CompactUploadIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadManager>(
      builder: (context, uploadManager, child) {
        if (!uploadManager.hasActiveUploads) {
          return const SizedBox.shrink();
        }

        final count = uploadManager.activeUploadCount;
        final progress = uploadManager.totalProgress;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppBorders.borderRadiusNormal,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
