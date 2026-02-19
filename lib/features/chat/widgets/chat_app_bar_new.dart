import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

class ChatHeaderConstants {
  static const double profileAvatarRadius = 18.0;
  static const double profileAvatarPadding = 8.0;
}

/// Reusable chat app bar header - extends PreferredSize for use in Scaffold
class ChatAppBar extends PreferredSize {
  ChatAppBar({
    super.key,
    required String title,
    String? profilePictureUrl,
    required VoidCallback onAudioCall,
    required VoidCallback onVideoCall,
    VoidCallback? onMediaManager,
    VoidCallback? onClearChat,
    VoidCallback? onDeleteChat,
  }) : super(
         preferredSize: const Size.fromHeight(kToolbarHeight),
         child: _ChatAppBarContent(
           title: title,
           profilePictureUrl: profilePictureUrl,
           onAudioCall: onAudioCall,
           onVideoCall: onVideoCall,
           onMediaManager: onMediaManager,
           onClearChat: onClearChat,
           onDeleteChat: onDeleteChat,
         ),
       );
}

/// Internal widget that renders the actual app bar content
class _ChatAppBarContent extends StatelessWidget {
  final String title;
  final String? profilePictureUrl;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final VoidCallback? onMediaManager;
  final VoidCallback? onClearChat;
  final VoidCallback? onDeleteChat;

  static const String _tag = 'ChatAppBar';
  final AppLogger _log = sl<AppLogger>();

  _ChatAppBarContent({
    required this.title,
    this.profilePictureUrl,
    required this.onAudioCall,
    required this.onVideoCall,
    this.onMediaManager,
    this.onClearChat,
    this.onDeleteChat,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      title: Row(
        children: [
          if (profilePictureUrl != null && profilePictureUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                right: ChatHeaderConstants.profileAvatarPadding,
              ),
              child: CachedNetworkImage(
                imageUrl: profilePictureUrl!,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: ChatHeaderConstants.profileAvatarRadius,
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => CircleAvatar(
                  radius: ChatHeaderConstants.profileAvatarRadius,
                  backgroundColor: AppColors.surfaceVariant,
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  radius: ChatHeaderConstants.profileAvatarRadius,
                  backgroundColor: AppColors.surfaceVariant,
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : 'U',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(
                right: ChatHeaderConstants.profileAvatarPadding,
              ),
              child: CircleAvatar(
                radius: ChatHeaderConstants.profileAvatarRadius,
                backgroundColor: AppColors.surfaceVariant,
                child: Text(
                  title.isNotEmpty ? title[0].toUpperCase() : 'U',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ),
          Expanded(child: Text(title, style: AppTypography.headingSmall)),
        ],
      ),
      actions: [
        // Audio call button
        IconButton(
          icon: const Icon(Icons.call, color: AppColors.white),
          onPressed: () {
            _log.debug('Audio call button tapped', tag: _tag);
            onAudioCall();
          },
          tooltip: 'Audio Call',
        ),
        // Video call button
        IconButton(
          icon: const Icon(Icons.videocam, color: AppColors.white),
          onPressed: () {
            _log.debug('Video call button tapped', tag: _tag);
            onVideoCall();
          },
          tooltip: 'Video Call',
        ),
        // More options menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.white),
          color: AppColors.surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case 'media_manager':
                onMediaManager?.call();
                break;
              case 'clear_chat':
                onClearChat?.call();
                break;
              case 'delete_chat':
                onDeleteChat?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            if (!kIsWeb && onMediaManager != null)
              const PopupMenuItem(
                value: 'media_manager',
                child: Row(
                  children: [
                    Icon(Icons.storage, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text('Manage Cache'),
                  ],
                ),
              ),
            if (onClearChat != null)
              const PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            if (onDeleteChat != null)
              const PopupMenuItem(
                value: 'delete_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: AppColors.error),
                    SizedBox(width: 12),
                    Text(
                      'Delete Chat',
                      style: TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
