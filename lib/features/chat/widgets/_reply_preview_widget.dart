import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import '_message_content_widget.dart';
import 'link_preview_widget.dart';

/// Builds reply preview display (quote bar above message)
/// Extracted from MessageBubble for better reusability
class ReplyPreviewWidget extends StatelessWidget {
  final Message repliedMessage;
  final Function(String)? onShowReplyImagePreview;
  final Function(Message)? onPlayReplyAudio;
  final Function(Message)? onPlayReplyVideo;
  final Widget? replyAudioWidget;
  final Widget? replyVideoWidget;
  final CacheManager? cacheManager;
  final String? roomId;
  final bool fromMe;

  const ReplyPreviewWidget({
    super.key,
    required this.repliedMessage,
    this.onShowReplyImagePreview,
    this.onPlayReplyAudio,
    this.onPlayReplyVideo,
    this.replyAudioWidget,
    this.replyVideoWidget,
    this.cacheManager,
    this.roomId,
    this.fromMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return _buildReplyQuote(context);
  }

  Widget _buildReplyQuote(BuildContext context) {
    // Build preview widget based on message type
    Widget previewWidget;
    VoidCallback? onTap;

    switch (repliedMessage.type) {
      case MessageType.image:
        if (repliedMessage.mediaUrl != null && repliedMessage.mediaUrl!.isNotEmpty) {
          // _ReplyImageThumbnail handles both encrypted and plain images,
          // including its own tap-to-preview logic.
          previewWidget = _ReplyImageThumbnail(
            message: repliedMessage,
            roomId: roomId,
            onShowImagePreview: onShowReplyImagePreview,
          );
          // onTap intentionally not set — handled inside _ReplyImageThumbnail
        } else {
          previewWidget = Container(
            width: 40,
            height: 40,
            color: AppColors.textSecondary,
            child: const Icon(Icons.image, size: AppIconSizes.medium, color: AppColors.white),
          );
        }
        break;
      case MessageType.video:
        if (replyVideoWidget != null) {
          previewWidget = replyVideoWidget!;
          onTap = null;
        } else {
          previewWidget = Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.videocam, size: AppIconSizes.standard, color: AppColors.white),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 12,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          );
          onTap = onPlayReplyVideo != null
              ? () => onPlayReplyVideo!(repliedMessage)
              : null;
        }
        break;
      case MessageType.audio:
        if (replyAudioWidget != null) {
          previewWidget = replyAudioWidget!;
          onTap = null;
        } else {
          previewWidget = Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.audio_file, size: AppIconSizes.medium, color: AppColors.white),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 10,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          );
          onTap = onPlayReplyAudio != null
              ? () => onPlayReplyAudio!(repliedMessage)
              : null;
        }
        break;
      case MessageType.doc:
        previewWidget = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.textSecondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.description,
            size: AppIconSizes.medium,
            color: AppColors.white,
          ),
        );
        onTap = () => MessageContentWidget.navigateToDocumentViewer(
          context,
          fileName: repliedMessage.fileName ??
              repliedMessage.metadata?['fileName'] as String? ??
              repliedMessage.text,
          mediaUrl: repliedMessage.mediaUrl,
          roomId: roomId,
          mediaKey: repliedMessage.mediaKey,
          mediaHash: repliedMessage.mediaHash,
        );
        break;
      case MessageType.callLog:
        previewWidget = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.textSecondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.call, size: AppIconSizes.medium, color: AppColors.white),
        );
        break;
      case MessageType.system:
        previewWidget = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.textSecondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.info, size: 20, color: AppColors.white),
        );
        break;
      case MessageType.text:
        final hasUrl = containsUrl(repliedMessage.text);

        if (hasUrl) {
          final url = extractFirstUrl(repliedMessage.text)!;
          // Use full LinkPreviewWidget — tap/launch handled internally
          previewWidget = LinkPreviewWidget(url: url, fromMe: fromMe);
        } else {
          previewWidget = Text(
            repliedMessage.text.isEmpty ? '[Message]' : repliedMessage.text,
            style: AppTypography.badge.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        }
        break;
    }

    if (onTap != null) {
      previewWidget = GestureDetector(onTap: onTap, child: previewWidget);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      child: Row(
        children: [
          Flexible(child: previewWidget),
        ],
      ),
    );
  }

}

/// Thumbnail for a replied-to image message.
/// Handles both encrypted (AES-GCM) and plain images.
class _ReplyImageThumbnail extends StatefulWidget {
  final Message message;
  final String? roomId;
  final Function(String)? onShowImagePreview;

  const _ReplyImageThumbnail({
    required this.message,
    this.roomId,
    this.onShowImagePreview,
  });

  @override
  State<_ReplyImageThumbnail> createState() => _ReplyImageThumbnailState();
}

class _ReplyImageThumbnailState extends State<_ReplyImageThumbnail> {
  Future<Uint8List?>? _decryptFuture;

  bool get _isEncrypted =>
      widget.message.isEncrypted && widget.message.mediaKey != null;

  @override
  void initState() {
    super.initState();
    if (_isEncrypted) {
      _decryptFuture = _loadDecryptedBytes();
    }
  }

  Future<Uint8List?> _loadDecryptedBytes() async {
    try {
      return await sl<MediaCacheService>().getDecryptedMediaBytes(
        widget.message.mediaUrl!,
        mediaKey: widget.message.mediaKey!,
        mediaHash: widget.message.mediaHash,
      );
    } catch (_) {
      return null;
    }
  }

  void _showFullPreview(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Image')),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEncrypted) {
      return FutureBuilder<Uint8List?>(
        future: _decryptFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 40,
              height: 40,
              color: AppColors.divider,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return Container(
              width: 40,
              height: 40,
              color: AppColors.textSecondary,
              child: const Icon(Icons.image, size: 20, color: AppColors.white),
            );
          }
          return GestureDetector(
            onTap: () => _showFullPreview(context, bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                bytes,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 40,
                  height: 40,
                  color: AppColors.textSecondary,
                  child: const Icon(Icons.broken_image, size: 20, color: AppColors.white),
                ),
              ),
            ),
          );
        },
      );
    }

    // Non-encrypted image
    return GestureDetector(
      onTap: widget.onShowImagePreview != null
          ? () => widget.onShowImagePreview!(widget.message.mediaUrl!)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: widget.message.mediaUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) =>
              Container(width: 40, height: 40, color: AppColors.divider),
          errorWidget: (context, url, error) => Container(
            width: 40,
            height: 40,
            color: AppColors.textSecondary,
            child: const Icon(Icons.broken_image, size: 20, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}
