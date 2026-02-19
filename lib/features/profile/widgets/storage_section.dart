import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/shared/services/media_cache_service.dart';
import 'package:greenhive_app/shared/widgets/app_button_variants.dart';

/// Widget for displaying and managing storage/cache section.
class StorageSection extends StatefulWidget {
  const StorageSection({super.key});

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  late Future<int> _cacheSizeFuture;
  final _mediaCacheService = MediaCacheService();

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  void _loadCacheSize() {
    _cacheSizeFuture = _mediaCacheService.getTotalAppCacheSizeBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _cacheSizeFuture,
      builder: (context, snapshot) {
        final cacheSize = snapshot.data ?? 0;
        final formattedSize = _mediaCacheService.formatCacheSize(cacheSize);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.storage, color: AppColors.textSecondary),
                title: Text(
                  'App Storage',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? 'Calculating...'
                      : formattedSize,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => _showClearCacheDialog(context),
                  child: Text(
                    'Clear',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final cacheSize = await _mediaCacheService.getTotalAppCacheSizeBytes();
    final formattedSize = _mediaCacheService.formatCacheSize(cacheSize);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Clear Cache',
          style: AppTypography.bodyEmphasis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will clear all cached media, downloaded files, recordings, and thumbnails.',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.spacing16),
            Text(
              'Total storage used: $formattedSize',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.pop(ctx),
            label: 'Cancel',
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => _clearCache(ctx),
            label: 'Clear Cache',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Clearing cache...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    await _mediaCacheService.clearAllAppCaches();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cache cleared successfully'),
        backgroundColor: AppColors.success,
      ),
    );

    // Refresh cache size
    setState(() {
      _loadCacheSize();
    });
  }
}
