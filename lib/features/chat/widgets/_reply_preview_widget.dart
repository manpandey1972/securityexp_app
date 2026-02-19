import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/shared/themes/app_icon_sizes.dart';
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

  const ReplyPreviewWidget({
    super.key,
    required this.repliedMessage,
    this.onShowReplyImagePreview,
    this.onPlayReplyAudio,
    this.onPlayReplyVideo,
    this.replyAudioWidget,
    this.replyVideoWidget,
    this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    return _buildReplyQuote();
  }

  Widget _buildReplyQuote() {
    // Build preview widget based on message type
    Widget previewWidget;
    VoidCallback? onTap;

    switch (repliedMessage.type) {
      case MessageType.image:
        if (repliedMessage.mediaUrl != null && repliedMessage.mediaUrl!.isNotEmpty) {
          previewWidget = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: repliedMessage.mediaUrl!,
              cacheManager: cacheManager,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 1),
              ),
              errorWidget: (context, url, error) => Container(
                width: 40,
                height: 40,
                color: AppColors.textSecondary,
                child: const Icon(Icons.broken_image, size: AppIconSizes.medium),
              ),
            ),
          );
          onTap = onShowReplyImagePreview != null
              ? () => onShowReplyImagePreview!(repliedMessage.mediaUrl!)
              : null;
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
          final textWithoutUrl = extractTextWithoutUrl(repliedMessage.text);
          final domain = _extractDomain(url);
          final platformInfo = _detectPlatform(url);

          previewWidget = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: platformInfo.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(platformInfo.icon, color: AppColors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        platformInfo.name ?? domain,
                        style: AppTypography.badge.copyWith(
                          color: platformInfo.color,
                          fontWeight: AppTypography.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (textWithoutUrl != null)
                        Text(
                          textWithoutUrl,
                          style: AppTypography.timestamp.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
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

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  _PlatformInfo _detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('youtube-nocookie.com')) {
      return _PlatformInfo(
        name: 'YouTube',
        icon: Icons.play_circle_filled,
        color: AppColors.error,
      );
    }
    if (lowerUrl.contains('instagram.com') || lowerUrl.contains('instagr.am')) {
      return _PlatformInfo(
        name: 'Instagram',
        icon: Icons.camera_alt,
        color: AppColors.surfaceVariant,
      );
    }
    if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      return _PlatformInfo(
        name: 'X (Twitter)',
        icon: Icons.alternate_email,
        color: AppColors.primary,
      );
    }
    if (lowerUrl.contains('facebook.com') ||
        lowerUrl.contains('fb.com') ||
        lowerUrl.contains('fb.watch')) {
      return _PlatformInfo(
        name: 'Facebook',
        icon: Icons.facebook,
        color: AppColors.primary,
      );
    }
    if (lowerUrl.contains('linkedin.com') || lowerUrl.contains('lnkd.in')) {
      return _PlatformInfo(
        name: 'LinkedIn',
        icon: Icons.business,
        color: AppColors.primary,
      );
    }
    if (lowerUrl.contains('tiktok.com')) {
      return _PlatformInfo(
        name: 'TikTok',
        icon: Icons.music_note,
        color: AppColors.textPrimary,
      );
    }
    if (lowerUrl.contains('reddit.com') || lowerUrl.contains('redd.it')) {
      return _PlatformInfo(
        name: 'Reddit',
        icon: Icons.forum,
        color: AppColors.error,
      );
    }

    return _PlatformInfo(
      name: null,
      icon: Icons.link,
      color: AppColors.primary,
    );
  }
}

class _PlatformInfo {
  final String? name;
  final IconData icon;
  final Color color;

  _PlatformInfo({required this.name, required this.icon, required this.color});
}
