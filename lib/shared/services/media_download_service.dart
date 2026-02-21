import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';
import 'package:securityexperts_app/features/chat/services/media_encryption_service.dart';
import 'media_cache_service.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';

class MediaDownloadService {
  final MediaCacheService _mediaCacheService;
  final MediaEncryptionService? _mediaEncryption;

  MediaDownloadService({
    MediaCacheService? mediaCacheService,
    MediaEncryptionService? mediaEncryption,
  })  : _mediaCacheService = mediaCacheService ?? MediaCacheService(),
        _mediaEncryption = mediaEncryption;

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

  /// Download an encrypted media file, decrypt it, and save to device.
  ///
  /// Downloads the encrypted file from [url], decrypts using [mediaKey],
  /// verifies integrity with [mediaHash], and saves to device storage.
  Future<void> downloadEncryptedMedia({
    required String url,
    required String filename,
    required String roomId,
    required String mediaKey,
    String? mediaHash,
  }) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (kIsWeb) {
          // Web cannot decrypt locally; open URL directly (would need
          // a service worker or client-side decryption in JS)
          await _downloadMediaWeb(url);
          return;
        }

        if (_mediaEncryption == null) {
          throw Exception('Media encryption service not available');
        }

        await _downloadAndDecryptNative(
          url: url,
          filename: filename,
          roomId: roomId,
          mediaKey: mediaKey,
          mediaHash: mediaHash,
        );
      },
      onError: (error) =>
          SnackbarService.show('Encrypted download error: $error'),
    );
  }

  /// Download encrypted bytes from [url], decrypt, and save to device.
  Future<void> _downloadAndDecryptNative({
    required String url,
    required String filename,
    required String roomId,
    required String mediaKey,
    String? mediaHash,
  }) async {
    // Download encrypted bytes
    final encryptedBytes = await _downloadRawBytes(url);

    // Decrypt
    final decryptedBytes = await _mediaEncryption!.decryptFile(
      encryptedBytes: encryptedBytes,
      mediaKey: mediaKey,
      mediaHash: mediaHash,
    );

    // Determine filename
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'bin';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = FileTypeHelper.generateDownloadFilename(
      '.$ext',
      timestamp,
    );

    // Save decrypted bytes to target directory
    final targetDir = await _getTargetDownloadDirectory();
    if (targetDir == null) {
      SnackbarService.show('Downloads directory not available');
      return;
    }

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final finalPath = '${targetDir.path}/$finalFileName';
    final file = File(finalPath);
    await file.writeAsBytes(decryptedBytes);

    SnackbarService.show('Saved to Files app: $finalFileName');
  }

  /// Download raw bytes from a URL.
  Future<Uint8List> _downloadRawBytes(String url) async {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final bytes = await response.expand((s) => s).toList();
    return Uint8List.fromList(bytes);
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
