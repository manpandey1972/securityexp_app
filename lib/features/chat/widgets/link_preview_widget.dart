import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Widget that displays a rich preview for URLs in chat messages
///
/// Supports common platforms: YouTube, Instagram, Twitter/X, articles, etc.
/// Uses OpenGraph metadata for previews with caching support.
class LinkPreviewWidget extends StatelessWidget {
  final String url;
  final bool fromMe;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  static const String _tag = 'LinkPreviewWidget';
  final AppLogger _log = sl<AppLogger>();

  LinkPreviewWidget({
    super.key,
    required this.url,
    required this.fromMe,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Check if URL is valid for preview
    if (!AnyLinkPreview.isValidLink(url)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: AnyLinkPreview.builder(
            link: url,
            cache: const Duration(days: 7),
            placeholderWidget: _buildPlaceholder(),
            errorWidget: _buildErrorWidget(),
            itemBuilder: (context, metadata, imageProvider, svgPicture) {
              return _buildPreviewCard(metadata, imageProvider);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(Metadata metadata, ImageProvider? imageProvider) {
    final hasImage = imageProvider != null && metadata.image != null;
    final platformInfo = _detectPlatform(url);
    final isYouTube =
        url.toLowerCase().contains('youtube') ||
        url.toLowerCase().contains('youtu.be');

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.messageBubble,
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview (if available)
          if (hasImage)
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Play button overlay for video content
                if (isYouTube)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: AppColors.white,
                          size: AppIconSizes.xlarge,
                        ),
                      ),
                    ),
                  ),
                // Platform badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildPlatformBadge(platformInfo),
                ),
              ],
            ),

          // Text content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Site name
                if (metadata.siteName != null && metadata.siteName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      metadata.siteName!.toUpperCase(),
                      style: AppTypography.captionSmall.copyWith(
                        color: platformInfo.color,
                        fontWeight: AppTypography.semiBold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Title
                if (metadata.title != null && metadata.title!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      metadata.title!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.white,
                        fontWeight: AppTypography.semiBold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Description
                if (metadata.desc != null && metadata.desc!.isNotEmpty)
                  Text(
                    metadata.desc!,
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                // URL domain
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _extractDomain(url),
                          style: AppTypography.captionTiny.copyWith(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(_PlatformInfo platformInfo) {
    if (platformInfo.name == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: platformInfo.color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(platformInfo.icon, color: AppColors.white, size: AppIconSizes.tiny),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.messageBubble,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    // Show a minimal styled card with domain info when metadata fetch fails
    // This happens often on web due to CORS, and for sites like Instagram/Twitter
    final platformInfo = _detectPlatform(url);
    final domain = _extractDomain(url);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.messageBubble,
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: platformInfo.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(platformInfo.icon, color: platformInfo.color, size: AppIconSizes.medium),
          ),
          const SizedBox(width: 12),
          // Domain and link info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  platformInfo.name?.toUpperCase() ?? domain.toUpperCase(),
                  style: AppTypography.captionSmall.copyWith(
                    color: platformInfo.color,
                    fontWeight: AppTypography.semiBold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to open link',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // External link icon
          Icon(
            Icons.open_in_new,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            size: AppIconSizes.small,
          ),
        ],
      ),
    );
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
        color: AppColors.primary,
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

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      var urlString = url;
      if (!urlString.startsWith('http://') &&
          !urlString.startsWith('https://')) {
        urlString = 'https://$urlString';
      }
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _log.error('Error launching URL: $e', tag: _tag);
    }
  }
}

/// Helper to extract the first URL from text
String? extractFirstUrl(String text) {
  final urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false);
  final match = urlRegex.firstMatch(text);
  if (match != null) {
    var url = text.substring(match.start, match.end);
    // Clean up trailing punctuation
    while (url.isNotEmpty && '.!?,;:)'.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
  return null;
}

/// Check if text contains a URL
bool containsUrl(String text) {
  return extractFirstUrl(text) != null;
}

/// Extract text without the URL (for showing accompanying message)
/// Returns null if the message is only a URL with no other text
String? extractTextWithoutUrl(String text) {
  final urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false);

  // Remove all URLs from text
  var textWithoutUrls = text.replaceAll(urlRegex, '').trim();

  // Clean up any remaining whitespace
  textWithoutUrls = textWithoutUrls.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Return null if nothing left (message was only URL)
  if (textWithoutUrls.isEmpty) {
    return null;
  }

  return textWithoutUrls;
}

class _PlatformInfo {
  final String? name;
  final IconData icon;
  final Color color;

  _PlatformInfo({required this.name, required this.icon, required this.color});
}
