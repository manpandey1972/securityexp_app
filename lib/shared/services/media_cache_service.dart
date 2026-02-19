import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:http/http.dart' as http;
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

// ============================================================================
// CUSTOM FILE SERVICE - Extracts proper file extensions from URLs
// ============================================================================

/// Custom HttpFileService that extracts file extensions from URLs instead of
/// relying on Content-Type headers. This prevents Firebase Storage URLs from
/// being saved with .bin extension when Content-Type is application/octet-stream.
class ExtensionAwareHttpFileService extends FileService {
  final http.Client _httpClient;

  ExtensionAwareHttpFileService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final req = http.Request('GET', Uri.parse(url));
    if (headers != null) {
      req.headers.addAll(headers);
    }
    final httpResponse = await _httpClient.send(req);

    // Extract extension from URL, falling back to Content-Type header
    final urlExtension = _extractExtensionFromUrl(url);

    return _ExtensionAwareHttpGetResponse(httpResponse, urlExtension);
  }

  /// Extract file extension from URL (before query params).
  /// Returns extension with leading dot (e.g., ".mp4", ".jpg").
  String _extractExtensionFromUrl(String url) {
    final source = url.split('?').first.toLowerCase();
    final parts = source.split('.');
    if (parts.length > 1) {
      final ext = parts.last;
      // Only use URL extension if it looks valid
      if (_validExtensions.contains(ext)) {
        return '.$ext';
      }
    }
    return ''; // Empty string means fall back to Content-Type
  }

  /// Valid media file extensions we recognize
  static const _validExtensions = {
    // Images
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'ico', 'tiff',
    // Videos
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp', 'wmv',
    // Audio
    'mp3', 'aac', 'm4a', 'wav', 'ogg', 'flac', 'wma', 'opus',
    // Documents
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf',
    // Archives
    'zip', 'rar', '7z', 'tar', 'gz',
  };
}

/// Custom HttpGetResponse that uses URL-extracted extension when available.
class _ExtensionAwareHttpGetResponse implements FileServiceResponse {
  final http.StreamedResponse _response;
  final String _urlExtension;
  final DateTime _receivedTime = DateTime.now();

  _ExtensionAwareHttpGetResponse(this._response, this._urlExtension);

  @override
  int get statusCode => _response.statusCode;

  String? _header(String name) => _response.headers[name];

  @override
  Stream<List<int>> get content => _response.stream;

  @override
  int? get contentLength => _response.contentLength;

  @override
  DateTime get validTill {
    // Without a cache-control header we keep the file for a week
    var ageDuration = const Duration(days: 7);
    final controlHeader = _header(HttpHeaders.cacheControlHeader);
    if (controlHeader != null) {
      final controlSettings = controlHeader.split(',');
      for (final setting in controlSettings) {
        final sanitizedSetting = setting.trim().toLowerCase();
        if (sanitizedSetting == 'no-cache') {
          ageDuration = Duration.zero;
        }
        if (sanitizedSetting.startsWith('max-age=')) {
          final validSeconds =
              int.tryParse(sanitizedSetting.split('=')[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }
    return _receivedTime.add(ageDuration);
  }

  @override
  String? get eTag => _header(HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    // Prefer URL extension if available
    if (_urlExtension.isNotEmpty) {
      return _urlExtension;
    }

    // Fall back to Content-Type header
    final contentTypeHeader = _header(HttpHeaders.contentTypeHeader);
    if (contentTypeHeader != null) {
      final contentType = ContentType.parse(contentTypeHeader);
      // Use MIME type mapping
      final mimeExt = _mimeToExtension[contentType.mimeType];
      if (mimeExt != null) {
        return mimeExt;
      }
      // Default to subType if no mapping found
      return '.${contentType.subType}';
    }

    return '.bin'; // Ultimate fallback
  }

  /// Common MIME type to extension mapping
  static const _mimeToExtension = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'image/bmp': '.bmp',
    'image/svg+xml': '.svg',
    'video/mp4': '.mp4',
    'video/quicktime': '.mov',
    'video/x-msvideo': '.avi',
    'video/webm': '.webm',
    'audio/mpeg': '.mp3',
    'audio/aac': '.aac',
    'audio/x-aac': '.aac',
    'audio/mp4': '.m4a',
    'audio/x-m4a': '.m4a',
    'audio/wav': '.wav',
    'audio/ogg': '.ogg',
    'application/pdf': '.pdf',
    'application/octet-stream': '.bin', // This is what we're trying to avoid
  };
}

// ============================================================================
// MEDIA CACHE SERVICE
// ============================================================================

class MediaCacheService {
  final _log = sl<AppLogger>();
  static const _tag = 'MediaCacheService';

  /// Helper to get the SharedPreferences key for a chat room's cache index.
  String _prefsKey(String chatRoomId) => 'media_cache_urls_v2_$chatRoomId';

  /// Add a URL to the chat room's cache index.
  Future<void> _addUrlToIndex(String chatRoomId, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(chatRoomId);
    final urls = prefs.getStringList(key) ?? [];

    if (!urls.contains(url)) {
      urls.add(url);
      await prefs.setStringList(key, urls);
    }
  }

  /// Remove a URL from the chat room's cache index.
  Future<void> _removeUrlFromIndex(String chatRoomId, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(chatRoomId);
    final urls = prefs.getStringList(key) ?? [];
    urls.remove(url);
    await prefs.setStringList(key, urls);
  }

  /// Get all URLs from the cache index.
  Future<List<String>> _getUrlsFromIndex(String chatRoomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(chatRoomId);
    return prefs.getStringList(key) ?? [];
  }

  /// Clear the chat room's cache index.
  Future<void> _clearIndex(String chatRoomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(chatRoomId);
    await prefs.remove(key);

    // Also clear legacy index if it exists
    final legacyKey = 'media_cache_urls_$chatRoomId';
    await prefs.remove(legacyKey);
  }

  static final MediaCacheService _instance = MediaCacheService._internal();
  final Map<String, CacheManager> _chatRoomManagers = {};

  MediaCacheService._internal();
  factory MediaCacheService() => _instance;

  /// Get or create a cache manager for a specific chat room.
  /// Made public to allow CachedNetworkImage to share the same cache.
  /// Uses ExtensionAwareHttpFileService to store files with proper extensions.
  CacheManager getManagerForRoom(String chatRoomId) {
    return _chatRoomManagers.putIfAbsent(
      chatRoomId,
      () => CacheManager(
        Config(
          'chatRoomCache_$chatRoomId',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
          fileService: ExtensionAwareHttpFileService(),
        ),
      ),
    );
  }

  /// Fetches a media file from cache or network URL for a chat room.
  /// Expects `url` to be a full download URL (e.g., from Firebase Storage).
  Future<FileInfo?> getMediaFile(String chatRoomId, String url) async {
    try {
      final manager = getManagerForRoom(chatRoomId);
      FileInfo? file = await manager.getFileFromCache(url);
      // If cached but file missing on disk, discard so we can redownload
      if (file != null && !file.file.existsSync()) {
        await manager.removeFile(url);
        await _removeUrlFromIndex(chatRoomId, url);
        file = null;
      }

      if (file != null) {
        // Ensure URL is in index
        await _addUrlToIndex(chatRoomId, url);
        _log.debug('Returning cached file: ${file.file.path}', tag: _tag);
        return file;
      }

      _log.debug('Downloading file from: $url', tag: _tag);
      final downloaded = await manager.downloadFile(url);
      await _addUrlToIndex(chatRoomId, url);
      _log.debug('Downloaded file to: ${downloaded.file.path}', tag: _tag);
      return downloaded;
    } catch (e, stackTrace) {
      _log.error('Error getting media file: $e', tag: _tag);
      _log.error('Stack trace: $stackTrace', tag: _tag);
      return null;
    }
  }

  /// Returns all cached files for a chat room.
  Future<List<FileInfo>> getAllCachedFiles(String chatRoomId) async {
    final manager = getManagerForRoom(chatRoomId);
    final urls = await _getUrlsFromIndex(chatRoomId);

    final List<FileInfo> files = [];

    for (final url in urls) {
      final fileInfo = await manager.getFileFromCache(url);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        files.add(fileInfo);
      } else {
        // Clean up stale index entries
        await manager.removeFile(url);
        await _removeUrlFromIndex(chatRoomId, url);
      }
    }

    return files;
  }

  /// Removes a cached file by URL for a chat room.
  Future<void> removeFile(String chatRoomId, String url) async {
    final manager = getManagerForRoom(chatRoomId);
    await manager.removeFile(url);
    await _removeUrlFromIndex(chatRoomId, url);
  }

  /// Clears all cached media files for a chat room.
  Future<void> clearCache(String chatRoomId) async {
    final manager = getManagerForRoom(chatRoomId);
    final urls = await _getUrlsFromIndex(chatRoomId);

    // Remove each file individually to ensure they're deleted
    for (final url in urls) {
      await ErrorHandler.handle<void>(
        operation: () async {
          await manager.removeFile(url);
          // Verify file was removed
          final cached = await manager.getFileFromCache(url);
          if (cached != null) {
            // debugPrint('[MEDIA_CACHE] File still exists after removeFile: $url, attempting direct deletion');
            if (cached.file.existsSync()) {
              await cached.file.delete();
              // debugPrint('[MEDIA_CACHE] Deleted file directly: ${cached.file.path}');
            }
          }
        },
        onError: (_) {
          // debugPrint('[MEDIA_CACHE] Error removing file $url: error');
        },
      );
    }

    // Also clear the entire cache manager
    // debugPrint('[MEDIA_CACHE] Calling manager.emptyCache()');
    await manager.emptyCache();

    // Clear the SharedPreferences index (with retries)
    // debugPrint('[MEDIA_CACHE] Clearing SharedPreferences index');
    await _clearIndex(chatRoomId);

    // Verify it's actually cleared
    final verifyPrefs = await SharedPreferences.getInstance();
    final verifyKey = _prefsKey(chatRoomId);
    verifyPrefs.get(verifyKey);

    // Clear the cache directory from disk as final cleanup
    await clearCacheDirectory(chatRoomId);
  }

  /// Clear cache directory directly from disk.
  /// This is a more aggressive approach than clearCache().
  Future<void> clearCacheDirectory(
    String chatRoomId, {
    bool clearPrefs = false,
  }) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return;

        // Get the temporary directory
        final tempDir = await getTemporaryDirectory();
        final roomCacheDir = Directory(
          '${tempDir.path}/chatRoomCache_$chatRoomId',
        );

        if (await roomCacheDir.exists()) {
          await roomCacheDir.delete(recursive: true);
        }

        // Only remove from SharedPreferences if explicitly requested
        // (clearCache() already handles this)
        if (clearPrefs) {
          await _clearIndex(chatRoomId);
        }

        _log.debug('Cache directory cleared', tag: _tag);
      },
      onError: (error) {
        _log.error('Error clearing cache directory: $error', tag: _tag);
      },
    );
  }

  // ========================================
  // CACHE SIZE MONITORING
  // ========================================

  /// Get the total cache size in bytes for a specific chat room.
  Future<int> getCacheSizeBytes(String chatRoomId) async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return 0;

        final tempDir = await getTemporaryDirectory();
        final roomCacheDir = Directory(
          '${tempDir.path}/chatRoomCache_$chatRoomId',
        );

        if (!await roomCacheDir.exists()) {
          return 0;
        }

        int totalSize = 0;
        await for (final entity in roomCacheDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }

        return totalSize;
      },
      fallback: 0,
      onError: (error) {
        _log.error('Error getting cache size: $error', tag: _tag);
      },
    );
  }

  /// Get the total cache size in bytes across all chat rooms.
  Future<int> getTotalCacheSizeBytes() async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return 0;

        final tempDir = await getTemporaryDirectory();
        int totalSize = 0;

        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is Directory && entity.path.contains('chatRoomCache_')) {
            await for (final file in entity.list(
              recursive: true,
              followLinks: false,
            )) {
              if (file is File) {
                totalSize += await file.length();
              }
            }
          }
        }

        return totalSize;
      },
      fallback: 0,
      onError: (error) {
        _log.error('Error getting total cache size: $error', tag: _tag);
      },
    );
  }

  /// Get human-readable cache size string (e.g., "12.5 MB").
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get a list of all cached room IDs.
  Future<List<String>> getCachedRoomIds() async {
    return await ErrorHandler.handle<List<String>>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return [];

        final tempDir = await getTemporaryDirectory();
        final roomIds = <String>[];

        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is Directory && entity.path.contains('chatRoomCache_')) {
            final dirName = entity.path.split('/').last;
            final roomId = dirName.replaceFirst('chatRoomCache_', '');
            roomIds.add(roomId);
          }
        }

        return roomIds;
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting cached room IDs: $error', tag: _tag),
    );
  }

  /// Clear all media caches across all chat rooms.
  Future<void> clearAllCaches() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final roomIds = await getCachedRoomIds();
        for (final roomId in roomIds) {
          await clearCache(roomId);
        }
        _chatRoomManagers.clear();
        _log.info('Cleared all media caches', tag: _tag);
      },
      onError: (error) {
        _log.error('Error clearing all caches: $error', tag: _tag);
      },
    );
  }

  /// Clear ALL app caches including:
  /// - Chat room media caches
  /// - Default CachedNetworkImage cache (profile pictures, avatars, carousel)
  /// - Any other temporary cached files
  /// - Orphaned recording files in Documents directory
  /// - Downloaded media files in Documents directory
  /// - Video thumbnails in temp directory
  ///
  /// Use this for a complete cache wipe (e.g., from settings).
  Future<void> clearAllAppCaches() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return;

        // 1. Clear all chat room caches
        await clearAllCaches();

        // 2. Clear the default CachedNetworkImage cache
        await DefaultCacheManager().emptyCache();
        _log.debug('Cleared DefaultCacheManager cache', tag: _tag);

        // 3. Clear any orphaned cache directories in temp folder
        final tempDir = await getTemporaryDirectory();
        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is Directory) {
            final dirName = entity.path.split('/').last;
            // Clear any cache-related directories
            if (dirName.startsWith('chatRoomCache_') ||
                dirName.startsWith('libCachedImageData') ||
                dirName.startsWith('flutter_cache')) {
              await entity.delete(recursive: true);
              _log.debug('Deleted cache directory: $dirName', tag: _tag);
            }
          }
          // Clean up orphaned temp files (thumbnails, temp downloads, recordings)
          if (entity is File) {
            final fileName = entity.path.split('/').last;
            if (fileName.startsWith('thumb_') ||
                fileName.startsWith('temp_') ||
                fileName.startsWith('recording_')) {
              await entity.delete();
              _log.debug('Deleted orphaned temp file: $fileName', tag: _tag);
            }
          }
        }

        // 4. Clean up orphaned files in Documents directory
        // (old recordings and downloads that were saved there before the fix)
        await _cleanupDocumentsDirectory();

        // 5. Clear all media cache SharedPreferences keys
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().toList();
        for (final key in keys) {
          if (key.startsWith('media_cache_') ||
              key.startsWith('media_cache_index_')) {
            await prefs.remove(key);
          }
        }
        _log.debug('Cleared all SharedPreferences cache keys', tag: _tag);
      },
      onError: (error) {
        _log.error('Error clearing all app caches: $error', tag: _tag);
      },
    );
  }

  /// Clean up orphaned files in Documents directory.
  /// These include old recording files and downloaded media that were
  /// previously saved to Documents before being moved to temp.
  Future<void> _cleanupDocumentsDirectory() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final docsDir = await getApplicationDocumentsDirectory();
        int deletedCount = 0;

        await for (final entity in docsDir.list(followLinks: false)) {
          if (entity is File) {
            final fileName = entity.path.split('/').last;
            // Clean up recording files (recording_<timestamp>.m4a)
            // Clean up media downloads (media_<timestamp>.<ext>)
            // Clean up document downloads (document_<timestamp>.<ext>)
            // Clean up generic downloads (file_<timestamp>.<ext>)
            if (fileName.startsWith('recording_') ||
                fileName.startsWith('media_') ||
                fileName.startsWith('document_') ||
                fileName.startsWith('file_')) {
              await entity.delete();
              deletedCount++;
            }
          }
        }

        if (deletedCount > 0) {
          _log.info(
            'Cleaned up $deletedCount orphaned file(s) from Documents',
            tag: _tag,
          );
        }
      },
      onError: (error) {
        _log.error('Error cleaning Documents directory: $error', tag: _tag);
      },
    );
  }

  /// Clear orphaned caches - caches for rooms that no longer exist for this user.
  ///
  /// [activeRoomIds] - List of room IDs the user currently has access to.
  /// Any cached room not in this list will be deleted.
  Future<int> clearOrphanedCaches(List<String> activeRoomIds) async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        final cachedRoomIds = await getCachedRoomIds();
        final activeSet = activeRoomIds.toSet();
        int deletedCount = 0;

        for (final cachedRoomId in cachedRoomIds) {
          if (!activeSet.contains(cachedRoomId)) {
            await clearCache(cachedRoomId);
            _chatRoomManagers.remove(cachedRoomId);
            deletedCount++;
          }
        }

        _log.info('Cleared $deletedCount orphaned cache(s)', tag: _tag);
        return deletedCount;
      },
      fallback: 0,
      onError: (error) {
        _log.error('Error clearing orphaned caches: $error', tag: _tag);
      },
    );
  }

  /// Get the total size of ALL app-managed storage in bytes.
  /// Includes:
  /// - Chat room media caches (temp dir)
  /// - Default CachedNetworkImage cache (temp dir)
  /// - Orphaned temp files: thumbnails, temp downloads, recordings (temp dir)
  /// - Orphaned files in Documents: old recordings and downloads
  ///
  /// This matches what iPhone Settings reports for the app.
  Future<int> getTotalAppCacheSizeBytes() async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return 0;

        int totalSize = 0;

        // 1. Temp directory: cache dirs + orphaned files
        final tempDir = await getTemporaryDirectory();
        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is Directory) {
            final dirName = entity.path.split('/').last;
            // Include all cache-related directories
            if (dirName.startsWith('chatRoomCache_') ||
                dirName.startsWith('libCachedImageData') ||
                dirName.startsWith('flutter_cache')) {
              await for (final file in entity.list(
                recursive: true,
                followLinks: false,
              )) {
                if (file is File) {
                  totalSize += await file.length();
                }
              }
            }
          }
          // Count orphaned temp files (thumbnails, temp downloads, recordings)
          if (entity is File) {
            final fileName = entity.path.split('/').last;
            if (fileName.startsWith('thumb_') ||
                fileName.startsWith('temp_') ||
                fileName.startsWith('recording_')) {
              totalSize += await entity.length();
            }
          }
        }

        // 2. Documents directory: old recordings and downloads
        final docsDir = await getApplicationDocumentsDirectory();
        await for (final entity in docsDir.list(followLinks: false)) {
          if (entity is File) {
            final fileName = entity.path.split('/').last;
            if (fileName.startsWith('recording_') ||
                fileName.startsWith('media_') ||
                fileName.startsWith('document_') ||
                fileName.startsWith('file_')) {
              totalSize += await entity.length();
            }
          }
        }

        return totalSize;
      },
      fallback: 0,
      onError: (error) {
        _log.error('Error getting total app cache size: $error', tag: _tag);
      },
    );
  }

  /// Clear legacy .bin files that may have been cached with wrong extension.
  /// This is useful when migrating from old caching strategy.
  Future<int> clearLegacyBinFiles(String chatRoomId) async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return 0;

        final tempDir = await getTemporaryDirectory();
        final roomCacheDir = Directory(
          '${tempDir.path}/chatRoomCache_$chatRoomId',
        );

        if (!await roomCacheDir.exists()) {
          return 0;
        }

        int deletedCount = 0;
        await for (final entity in roomCacheDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File && entity.path.endsWith('.bin')) {
            await entity.delete();
            deletedCount++;
          }
        }

        // Clear the index to force re-download
        await _clearIndex(chatRoomId);

        return deletedCount;
      },
      fallback: 0,
      onError: (error) =>
          _log.error('Error clearing legacy files: $error', tag: _tag),
    );
  }

  /// Clear all legacy .bin files across all chat rooms.
  Future<int> clearAllLegacyBinFiles() async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        final roomIds = await getCachedRoomIds();
        int totalDeleted = 0;
        for (final roomId in roomIds) {
          totalDeleted += await clearLegacyBinFiles(roomId);
        }
        _log.info('Total legacy .bin files deleted: $totalDeleted', tag: _tag);
        return totalDeleted;
      },
      fallback: 0,
      onError: (error) =>
          _log.error('Error clearing all legacy files: $error', tag: _tag),
    );
  }

  /// Get count of .bin files in cache (for diagnostics).
  Future<int> getBinFileCount(String chatRoomId) async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        // MediaCacheService is only relevant for mobile platforms
        if (kIsWeb) return 0;

        final tempDir = await getTemporaryDirectory();
        final roomCacheDir = Directory(
          '${tempDir.path}/chatRoomCache_$chatRoomId',
        );

        if (!await roomCacheDir.exists()) return 0;

        int count = 0;
        await for (final entity in roomCacheDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File && entity.path.endsWith('.bin')) {
            count++;
          }
        }
        return count;
      },
      fallback: 0,
      onError: (error) =>
          _log.error('Error counting .bin files: $error', tag: _tag),
    );
  }
}
