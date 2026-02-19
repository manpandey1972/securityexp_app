import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/features/chat/widgets/video_widgets.dart';

/// Handles navigation and preview operations in chat
class ChatNavigationHelper {
  final BuildContext context;
  final String roomId;

  ChatNavigationHelper(this.context, {this.roomId = 'global'});

  /// Show image preview in full screen
  Future<void> showImagePreview(String source) async {
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
  void openVideoPlayer(String url) {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(url: url, roomId: roomId),
        ),
      );
    } catch (e, stackTrace) {
      sl<AppLogger>().error('Error opening video', tag: 'ChatNavigationHelper', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening video: $e')));
    }
  }
}
