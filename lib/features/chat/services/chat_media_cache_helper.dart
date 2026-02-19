import 'dart:async';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';

/// Manages media caching with LRU eviction policy and parallel prefetching
class ChatMediaCacheHelper {
  final Map<String, Future<FileInfo?>> _mediaFileFutures = {};
  final Map<String, DateTime> _normalizedDateCache = {};
  final MediaCacheService _mediaCacheService;
  final String _roomId;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'ChatMediaCacheHelper';

  /// Maximum concurrent downloads during prefetch
  static const int _maxConcurrentDownloads = 3;

  ChatMediaCacheHelper({
    required MediaCacheService mediaCacheService,
    required String roomId,
  }) : _mediaCacheService = mediaCacheService,
       _roomId = roomId;

  /// Get the cache manager for this room (for CachedNetworkImage integration)
  CacheManager get cacheManager =>
      _mediaCacheService.getManagerForRoom(_roomId);

  /// Get cached media file future with LRU eviction
  /// Includes a timeout to prevent hanging forever on slow/failed downloads
  Future<FileInfo?> getCachedMediaFileFuture(String mediaUrl) {
    // Return cached future if it exists, otherwise create and cache it
    if (!_mediaFileFutures.containsKey(mediaUrl)) {
      // Implement simple LRU: if cache is full, remove oldest (first) entry
      if (_mediaFileFutures.length >= ChatConstants.mediaCacheLimit) {
        final firstKey = _mediaFileFutures.keys.first;
        _mediaFileFutures.remove(firstKey);
      }
      // Add timeout to prevent hanging forever
      _mediaFileFutures[mediaUrl] = _mediaCacheService
          .getMediaFile(_roomId, mediaUrl)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              _log.warning('Timeout fetching media: $mediaUrl', tag: _tag);
              return null;
            },
          );
    }
    return _mediaFileFutures[mediaUrl]!;
  }

  /// Get normalized date (year/month/day) from cache to avoid repeated object creation
  DateTime getNormalizedDate(DateTime dateTime) {
    final key = '${dateTime.year}-${dateTime.month}-${dateTime.day}';
    if (!_normalizedDateCache.containsKey(key)) {
      _normalizedDateCache[key] = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );
    }
    return _normalizedDateCache[key]!;
  }

  /// Prefetch all media URLs in the given message list with parallel downloads.
  /// Uses a concurrency limit to avoid overwhelming the network.
  Future<void> prefetchAllMedia(List<dynamic> messages) async {
    final mediaUrls = messages
        .where((m) => m.mediaUrl != null && m.mediaUrl!.isNotEmpty)
        .map((m) => m.mediaUrl! as String)
        .toList();

    await _prefetchUrls(mediaUrls);
  }

  /// Prefetch visible media plus a lookahead buffer.
  /// This is more efficient than prefetching all media at once.
  ///
  /// [visibleStartIndex] - The index of the first visible message
  /// [visibleEndIndex] - The index of the last visible message
  /// [messages] - The full list of messages
  /// [lookahead] - Number of messages to prefetch beyond visible range (default: 10)
  Future<void> prefetchVisibleMedia(
    List<dynamic> messages, {
    int visibleStartIndex = 0,
    int visibleEndIndex = 0,
    int lookahead = 10,
  }) async {
    if (messages.isEmpty) return;

    // Calculate the range to prefetch (visible + lookahead)
    final startIndex = (visibleStartIndex - lookahead).clamp(
      0,
      messages.length - 1,
    );
    final endIndex = (visibleEndIndex + lookahead).clamp(
      0,
      messages.length - 1,
    );

    final mediaUrls = <String>[];
    for (int i = startIndex; i <= endIndex; i++) {
      final message = messages[i];
      if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
        mediaUrls.add(message.mediaUrl! as String);
      }
    }

    if (mediaUrls.isNotEmpty) {
      _log.debug(
        'Prefetching ${mediaUrls.length} media files (range: $startIndex-$endIndex)',
        tag: _tag,
      );
      await _prefetchUrls(mediaUrls);
    }
  }

  /// Warm the cache with recent media (for initial chat load).
  /// Prefetches the most recent [count] media messages.
  Future<void> warmCache(List<dynamic> messages, {int count = 20}) async {
    if (messages.isEmpty) return;

    // Get the most recent messages with media (assuming messages are sorted oldest first)
    final recentMessages = messages.reversed
        .where((m) => m.mediaUrl != null && m.mediaUrl!.isNotEmpty)
        .take(count)
        .toList();

    final mediaUrls = recentMessages.map((m) => m.mediaUrl! as String).toList();

    if (mediaUrls.isNotEmpty) {
      _log.debug(
        'Warming cache with ${mediaUrls.length} recent media files',
        tag: _tag,
      );
      await _prefetchUrls(mediaUrls);
    }
  }

  /// Internal method to prefetch URLs with concurrency limit.
  Future<void> _prefetchUrls(List<String> urls) async {
    if (urls.isEmpty) return;

    // Use a pool of concurrent downloads
    final pool = <Future<void>>[];

    for (final url in urls) {
      // Add download to pool
      final downloadFuture = ErrorHandler.handle<void>(
        operation: () async {
          await _mediaCacheService.getMediaFile(_roomId, url);
        },
        onError: (_) {
          // Ignore individual failures; we only prefetch best-effort
        },
      );
      pool.add(downloadFuture);

      // If pool is at max capacity, wait for one to complete
      if (pool.length >= _maxConcurrentDownloads) {
        await Future.any(pool);
        // Remove completed futures
        pool.removeWhere((f) => f == Future.value(null));
      }
    }

    // Wait for remaining downloads
    if (pool.isNotEmpty) {
      await Future.wait(pool);
    }
  }

  /// Check if a URL is already cached (without downloading).
  Future<bool> isUrlCached(String url) async {
    final manager = _mediaCacheService.getManagerForRoom(_roomId);
    final fileInfo = await manager.getFileFromCache(url);
    return fileInfo != null && fileInfo.file.existsSync();
  }

  /// Clear all cached futures and dates
  void clearCache() {
    _mediaFileFutures.clear();
    _normalizedDateCache.clear();
  }
}
