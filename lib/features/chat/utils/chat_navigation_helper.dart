import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/features/chat/widgets/video_widgets.dart';

/// Handles navigation and preview operations in chat
class ChatNavigationHelper {
  final BuildContext context;
  final String roomId;

  ChatNavigationHelper(this.context, {this.roomId = 'global'});

  /// Show image preview in full screen
  ///
  /// Supports encrypted images via [mediaKey]/[mediaHash] — will download,
  /// decrypt, and display the image.
  Future<void> showImagePreview(
    String source, {
    String? mediaKey,
    String? mediaHash,
  }) async {
    if (mediaKey != null) {
      return _showEncryptedImagePreview(source, mediaKey, mediaHash);
    }

    final isLocalFile = source.startsWith('/') || source.startsWith('file://');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (innerContext) => Scaffold(
          appBar: AppBar(
            title: const Text('Image'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: isLocalFile
                  ? Image.file(
                      File(
                        source.startsWith('file://')
                            ? source.substring(7)
                            : source,
                      ),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: AppIconSizes.hero),
                              SizedBox(height: 16),
                              Text('Image failed to load'),
                            ],
                          ),
                    )
                  : CachedNetworkImage(
                      imageUrl: source,
                      fit: BoxFit.contain,
                      placeholder: (context, _) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: AppIconSizes.hero),
                          SizedBox(height: 16),
                          Text('Image failed to load'),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Open URL in external browser
  Future<void> openUrl(String url, [BuildContext? ctx]) async {
    final messengerContext = ctx ?? context;
    final messenger = ScaffoldMessenger.of(messengerContext);
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Cannot open URL')),
        );
      }
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Open URL failed', tag: 'ChatNavigationHelper', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(SnackBar(content: Text('Open URL failed: $e')));
    }
  }

  /// Open video player in full screen
  ///
  /// Supports encrypted videos via [mediaKey]/[mediaHash] — will download,
  /// decrypt, and play the video.
  void openVideoPlayer(
    String url, {
    String? mediaKey,
    String? mediaHash,
  }) {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(
            url: url,
            roomId: roomId,
            mediaKey: mediaKey,
            mediaHash: mediaHash,
          ),
        ),
      );
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Error opening video', tag: 'ChatNavigationHelper', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening video: $e')));
    }
  }

  /// Download and decrypt an encrypted image, then show full-screen preview.
  Future<void> _showEncryptedImagePreview(
    String source,
    String mediaKey,
    String? mediaHash,
  ) async {
    Uint8List? bytes;

    try {
      final mediaCacheService = sl<MediaCacheService>();

      if (kIsWeb) {
        bytes = await mediaCacheService.getDecryptedMediaBytes(
          source,
          mediaKey: mediaKey,
          mediaHash: mediaHash,
        );
      } else {
        final fileInfo = await mediaCacheService.getEncryptedMediaFile(
          roomId,
          source,
          mediaKey: mediaKey,
          mediaHash: mediaHash,
        );
        if (fileInfo != null && fileInfo.file.existsSync()) {
          bytes = await fileInfo.file.readAsBytes();
        } else {
          bytes = await mediaCacheService.getDecryptedMediaBytes(
            source,
            mediaKey: mediaKey,
            mediaHash: mediaHash,
          );
        }
      }
    } catch (e) {
      sl<AppLogger>().error(
        'Failed to decrypt image for preview',
        tag: 'ChatNavigationHelper',
        error: e,
      );
    }

    if (!context.mounted) return;

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to decrypt image')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (innerContext) => Scaffold(
          appBar: AppBar(title: const Text('Image')),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                bytes!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: AppIconSizes.hero),
                    SizedBox(height: 16),
                    Text('Image failed to load'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
