import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_cache_helper.dart';
import 'package:securityexperts_app/features/chat/widgets/video_widgets.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/utils/web_blob_url.dart' as blob_helper;

/// Reusable widget for rendering video messages with caching support.
///
/// Uses [StatefulWidget] to cache the decryption/cache-lookup future so that
/// parent rebuilds (e.g. from typing in the text field) do not re-trigger
/// expensive download + decrypt operations.
class MessageVideoWidget extends StatefulWidget {
  final String videoUrl;
  final ChatMediaCacheHelper cacheHelper;
  final VoidCallback onTapExpand;
  final VoidCallback? onTapDownload;
  final String? mediaKey;
  final String? mediaHash;
  final String? mediaType;
  final String? roomId;

  const MessageVideoWidget({
    super.key,
    required this.videoUrl,
    required this.cacheHelper,
    required this.onTapExpand,
    this.onTapDownload,
    this.mediaKey,
    this.mediaHash,
    this.mediaType,
    this.roomId,
  });

  @override
  State<MessageVideoWidget> createState() => _MessageVideoWidgetState();
}

class _MessageVideoWidgetState extends State<MessageVideoWidget> {
  static const String _tag = 'MessageVideoWidget';
  final AppLogger _log = sl<AppLogger>();

  bool get _isEncrypted => widget.mediaKey != null;

  // Cached futures — created once in initState, survive parent rebuilds.
  Future<FileInfo?>? _cacheLookupFuture;
  Future<FileInfo?>? _encryptedFileFuture;
  Future<Uint8List?>? _encryptedBytesFuture;

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  void _initFutures() {
    if (_isEncrypted) {
      final mediaCacheService = sl<MediaCacheService>();
      if (kIsWeb) {
        _encryptedBytesFuture = mediaCacheService.getDecryptedMediaBytes(
          widget.videoUrl,
          mediaKey: widget.mediaKey!,
          mediaHash: widget.mediaHash,
        );
      } else {
        final effectiveRoomId = widget.roomId ?? 'global';
        _encryptedFileFuture = mediaCacheService.getEncryptedMediaFile(
          effectiveRoomId,
          widget.videoUrl,
          mediaKey: widget.mediaKey!,
          mediaHash: widget.mediaHash,
          fileExtension: _videoExtension(),
        );
      }
    } else {
      _cacheLookupFuture =
          widget.cacheHelper.getCachedMediaFileFuture(widget.videoUrl);
    }
  }

  @override
  void didUpdateWidget(covariant MessageVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-create futures if the actual media URL or key changed
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.mediaKey != widget.mediaKey) {
      _initFutures();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEncrypted) {
      return _buildEncryptedVideo();
    }

    return FutureBuilder<FileInfo?>(
      future: _cacheLookupFuture,
      builder: (context, snapshot) {
        final cachedFile = snapshot.data;
        final isCached = cachedFile != null && cachedFile.file.existsSync();

        // Web: Always use network video player
        if (kIsWeb) {
          return InlineVideoPreview(
            videoUrl: widget.videoUrl,
            onTapExpand: widget.onTapExpand,
            onTapDownload: widget.onTapDownload,
          );
        }

        // Mobile: Show loading indicator while checking cache
        if (snapshot.connectionState == ConnectionState.waiting && !isCached) {
          return _buildLoadingPlaceholder();
        }

        // Mobile: Handle errors - fallback to network video
        if (snapshot.hasError) {
          _log.warning(
            'Cache error: ${snapshot.error}, falling back to network',
            tag: _tag,
          );
          return InlineVideoPreview(
            videoUrl: widget.videoUrl,
            onTapExpand: widget.onTapExpand,
            onTapDownload: widget.onTapDownload,
          );
        }

        // Mobile: Use cached video if available
        if (isCached) {
          return InlineCachedVideoPreview(
            cachedFileInfo: cachedFile,
            onTapExpand: widget.onTapExpand,
            onTapDownload: widget.onTapDownload,
          );
        }

        // Mobile: Fallback to network video
        return InlineVideoPreview(
          videoUrl: widget.videoUrl,
          onTapExpand: widget.onTapExpand,
          onTapDownload: widget.onTapDownload,
        );
      },
    );
  }

  Widget _buildEncryptedVideo() {
    if (kIsWeb) {
      return FutureBuilder<Uint8List?>(
        future: _encryptedBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingPlaceholder();
          }

          final bytes = snapshot.data;
          if (bytes != null) {
            final blobUrl = blob_helper.createBlobUrl(bytes, 'video/mp4');
            if (blobUrl != null) {
              return InlineVideoPreview(
                videoUrl: blobUrl,
                onTapExpand: widget.onTapExpand,
                onTapDownload: widget.onTapDownload,
              );
            }
          }

          _log.warning(
              'Failed to decrypt video for inline preview (web)', tag: _tag);
          return _buildDecryptionFailedPlaceholder();
        },
      );
    }

    return FutureBuilder<FileInfo?>(
      future: _encryptedFileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder();
        }

        final fileInfo = snapshot.data;
        if (fileInfo != null && fileInfo.file.existsSync()) {
          return InlineCachedVideoPreview(
            cachedFileInfo: fileInfo,
            onTapExpand: widget.onTapExpand,
            onTapDownload: widget.onTapDownload,
          );
        }

        _log.warning('Failed to decrypt video for inline preview', tag: _tag);
        return _buildDecryptionFailedPlaceholder();
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
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

  Widget _buildDecryptionFailedPlaceholder() {
    return Container(
      width: 180,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, color: AppColors.textSecondary, size: 32),
            SizedBox(height: 4),
            Text(
              'Cannot decrypt',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _videoExtension() {
    if (widget.mediaType == null) return '.mp4';
    switch (widget.mediaType!) {
      case 'video/mp4':
        return '.mp4';
      case 'video/quicktime':
        return '.mov';
      case 'video/webm':
        return '.webm';
      case 'video/x-matroska':
        return '.mkv';
      default:
        return '.mp4';
    }
  }
}
