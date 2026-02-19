import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/features/chat/utils/chat_utils.dart';
import 'media_cache_service.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';

class MediaDownloadService {
  final MediaCacheService _mediaCacheService;

  MediaDownloadService({MediaCacheService? mediaCacheService})
    : _mediaCacheService = mediaCacheService ?? MediaCacheService();

  /// Download media file to device storage or open in browser
  /// On web: opens the download URL in a new tab
  /// On mobile: saves file to appropriate directory
  Future<void> downloadMedia(String url, String filename, String roomId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (kIsWeb) {
          await _downloadMediaWeb(url);
          return;
        }

        await _downloadMediaNative(url, filename, roomId);
      },
      onError: (error) => SnackbarService.show('Download error: $error'),
    );
  }

  /// Open download URL in browser (web only)
  Future<void> _downloadMediaWeb(String url) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          SnackbarService.show('Cannot open download link');
        }
      },
      onError: (error) =>
          SnackbarService.show('Failed to open download link: $error'),
    );
  }

  /// Download and save media file to native device storage
  Future<void> _downloadMediaNative(
    String url,
    String filename,
    String roomId,
  ) async {
    // Get file extension from filename
    String ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'bin';

    // Generate timestamp-based filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = FileTypeHelper.generateDownloadFilename(
      '.$ext',
      timestamp,
    );

    // Try to get from cache first
    final fileInfo = await _mediaCacheService.getMediaFile(roomId, url);
    File sourceFile;
    bool isTemporaryDownload = false;

    if (fileInfo != null) {
      sourceFile = fileInfo.file;
    } else {
      // Fallback: download manually if not found in cache
      sourceFile = await _downloadToTemporaryFile(url, ext, timestamp);
      isTemporaryDownload = true;
    }

    // Save to appropriate directory based on platform
    final targetDir = await _getTargetDownloadDirectory();

    if (targetDir == null) {
      SnackbarService.show('Downloads directory not available');
      return;
    }

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final finalPath = '${targetDir.path}/$finalFileName';
    await sourceFile.copy(finalPath);

    // Clean up temporary download file (not the cache copy)
    if (isTemporaryDownload) {
      try {
        if (sourceFile.existsSync()) {
          await sourceFile.delete();
        }
      } catch (_) {
        // Best effort cleanup
      }
    }

    SnackbarService.show('Saved to Files app: $finalFileName');
  }

  /// Download file to temporary directory
  Future<File> _downloadToTemporaryFile(
    String url,
    String ext,
    int timestamp,
  ) async {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final bytes = await response.expand((s) => s).toList();
    final dir = await getTemporaryDirectory();
    final tempPath = path.join(dir.path, 'temp_$timestamp.$ext');
    final file = File(tempPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Get the appropriate download directory for the platform
  Future<Directory?> _getTargetDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    } else {
      return getDownloadsDirectory();
    }
  }
}
