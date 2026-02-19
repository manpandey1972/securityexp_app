import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:greenhive_app/features/chat/services/chat_media_cache_helper.dart';
import 'package:greenhive_app/features/chat/widgets/video_widgets.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Reusable widget for rendering video messages with caching support
class MessageVideoWidget extends StatelessWidget {
  final String videoUrl;
  final ChatMediaCacheHelper cacheHelper;
  final VoidCallback onTapExpand;
  final VoidCallback? onTapDownload;

  static const String _tag = 'MessageVideoWidget';
  final AppLogger _log = sl<AppLogger>();

  MessageVideoWidget({
    super.key,
    required this.videoUrl,
    required this.cacheHelper,
    required this.onTapExpand,
    this.onTapDownload,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FileInfo?>(
      future: cacheHelper.getCachedMediaFileFuture(videoUrl),
      builder: (context, snapshot) {
        final cachedFile = snapshot.data;
        final isCached = cachedFile != null && cachedFile.file.existsSync();

        // Web: Always use network video player
        if (kIsWeb) {
          return InlineVideoPreview(
            videoUrl: videoUrl,
            onTapExpand: onTapExpand,
            onTapDownload: onTapDownload,
          );
        }

        // Mobile: Show loading indicator while checking cache
        if (snapshot.connectionState == ConnectionState.waiting && !isCached) {
          return Container(
            width: 180,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // Mobile: Handle errors - fallback to network video
        if (snapshot.hasError) {
          _log.warning(
            'Cache error: ${snapshot.error}, falling back to network',
            tag: _tag,
          );
          return InlineVideoPreview(
            videoUrl: videoUrl,
            onTapExpand: onTapExpand,
            onTapDownload: onTapDownload,
          );
        }

        // Mobile: Use cached video if available
        if (isCached) {
          return InlineCachedVideoPreview(
            cachedFileInfo: cachedFile,
            onTapExpand: onTapExpand,
            onTapDownload: onTapDownload,
          );
        }

        // Mobile: Fallback to network video
        return InlineVideoPreview(
          videoUrl: videoUrl,
          onTapExpand: onTapExpand,
          onTapDownload: onTapDownload,
        );
      },
    );
  }
}
