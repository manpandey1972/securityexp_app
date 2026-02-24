import 'package:flutter/material.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/models/chat_message_actions.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_cache_helper.dart';
import 'package:securityexperts_app/shared/services/media_download_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_scroll_handler.dart';
import 'package:securityexperts_app/features/chat/widgets/message_bubble.dart';
import 'package:securityexperts_app/features/chat/widgets/swipeable_message.dart';
import 'package:securityexperts_app/features/chat/widgets/call_log_message_widget.dart';
import 'package:securityexperts_app/features/chat/widgets/date_separator_widget.dart';
import 'package:securityexperts_app/features/chat/widgets/message_video_widget.dart';
import 'package:securityexperts_app/features/chat/widgets/video_widgets.dart';
import 'package:securityexperts_app/features/chat/widgets/audio_widgets.dart';
import 'package:securityexperts_app/features/chat/widgets/document_message_bubble.dart';
import 'package:securityexperts_app/features/chat/widgets/_message_content_widget.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';

/// Individual message list item with date separator and message bubble
class ChatMessageListItem extends StatelessWidget {
  final Message message;
  final Message? previousMessage; // For date separator logic
  final bool fromMe;
  final bool isLastMessageFromUser;
  final String? partnerName;
  final ChatMessageActions actions;
  final ChatMediaCacheHelper cacheHelper;
  final MediaDownloadService mediaDownloadService;
  final ChatScrollHandler scrollHandler;
  final List<Message> allMessages;
  final String roomId;
  final String currentUserId;

  const ChatMessageListItem({
    super.key,
    required this.message,
    this.previousMessage,
    required this.fromMe,
    required this.isLastMessageFromUser,
    this.partnerName,
    required this.actions,
    required this.cacheHelper,
    required this.mediaDownloadService,
    required this.scrollHandler,
    required this.allMessages,
    required this.roomId,
    required this.currentUserId,
  });

  bool _shouldShowDateSeparator() {
    // Always show separator for the newest message
    if (previousMessage == null) {
      return true;
    }

    // Check if date changed compared to previous message (newer in time)
    final currentDate = cacheHelper.getNormalizedDate(
      message.timestamp.toDate(),
    );
    final prevDate = cacheHelper.getNormalizedDate(
      previousMessage!.timestamp.toDate(),
    );

    return currentDate != prevDate;
  }

  @override
  Widget build(BuildContext context) {
    final showSeparator = _shouldShowDateSeparator();
    final dateSeparator = showSeparator
        ? DateSeparatorWidget(date: message.timestamp.toDate())
        : null;

    // Handle call log messages
    if (message.type == MessageType.callLog) {
      return Column(
        key: ValueKey('call_log_${message.id}'),
        children: [
          if (dateSeparator != null) dateSeparator,
          CallLogMessageWidget(message: message, fromMe: fromMe),
        ],
      );
    }

    // Handle regular messages
    return Column(
      key: ValueKey('message_${message.id}'),
      children: [
        if (dateSeparator != null) dateSeparator,
        SwipeableMessage(
          onReply: () => actions.onReply(message),
          enabled: true,
          fromMe: fromMe,
          child: Builder(
            builder: (context) => MessageBubble(
            message: message,
            fromMe: fromMe,
            isLastMessageFromUser: isLastMessageFromUser,
            partnerName: partnerName,
            cacheManager: cacheHelper.cacheManager,
            roomId: roomId,
            onDelete: () => actions.onDelete(message),
            onReply: actions.onReply,
            onEdit: (msg, originalText) => actions.onEdit(msg, originalText),
            onShowImagePreview: actions.onShowImagePreview,
            onPlayAudio: actions.onPlayAudio,
            // Audio widget for main message
            audioWidget: message.type == MessageType.audio
                ? InlineAudioPlayer(
                    audioUrl: message.mediaUrl!,
                    filename: message.text.isNotEmpty ? message.text : 'Audio',
                    fromMe: fromMe,
                    roomId: roomId,
                    mediaKey: message.mediaKey,
                    mediaHash: message.mediaHash,
                    mediaType: message.mediaType,
                  )
                : null,
            // Video widget for main message
            videoWidget: message.type == MessageType.video
                ? MessageVideoWidget(
                    videoUrl: message.mediaUrl!,
                    cacheHelper: cacheHelper,
                    onTapExpand: () {
                      if (message.isEncrypted && message.mediaKey != null) {
                        // Navigate directly to encrypted-aware video player
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerPage(
                              url: message.mediaUrl!,
                              roomId: roomId,
                              mediaKey: message.mediaKey,
                              mediaHash: message.mediaHash,
                            ),
                          ),
                        );
                      } else {
                        actions.onPlayVideo(message.mediaUrl!);
                      }
                    },
                    mediaKey: message.mediaKey,
                    mediaHash: message.mediaHash,
                    mediaType: message.mediaType,
                    roomId: roomId,
                  )
                : null,
            // Document widget for main message
            documentWidget: message.type == MessageType.doc
                ? DocumentMessageBubble(
                    fileName: message.metadata?['fileName'] ?? message.text,
                    fileSize: _formatFileSize(message.metadata?['fileSize'] as int?),
                    mediaUrl: message.mediaUrl,
                    fromMe: fromMe,
                    onTap: () {
                      MessageContentWidget.navigateToDocumentViewer(
                        context,
                        fileName: message.metadata?['fileName'] ?? message.text,
                        mediaUrl: message.mediaUrl,
                        roomId: roomId,
                        mediaKey: message.mediaKey,
                        mediaHash: message.mediaHash,
                      );
                    },
                  )
                : null,
            // Callbacks for reply media
            onPlayReplyAudio: (repliedMsg) {
              if (repliedMsg.mediaUrl == null) return;
              scrollHandler.scrollToMessage(repliedMsg, allMessages);
            },
            onPlayReplyVideo: actions.onPlayReplyVideo,
            onShowReplyImagePreview: actions.onShowReplyImagePreview,
            // Audio widget for reply
            replyAudioWidget:
                message.replyToMessage?.type == MessageType.audio &&
                    message.replyToMessage?.mediaUrl != null &&
                    message.replyToMessage!.mediaUrl!.isNotEmpty
                ? InlineAudioPlayer(
                    audioUrl: message.replyToMessage!.mediaUrl!,
                    filename: message.replyToMessage!.text.isNotEmpty
                        ? message.replyToMessage!.text
                        : 'Audio',
                    fromMe:
                        message.replyToMessage!.senderId ==
                        currentUserId,
                    roomId: roomId,
                    mediaKey: message.replyToMessage!.mediaKey,
                    mediaHash: message.replyToMessage!.mediaHash,
                    mediaType: message.replyToMessage!.mediaType,
                    onTapDownload: () {
                      final replyMsg = message.replyToMessage!;
                      if (replyMsg.isEncrypted && replyMsg.mediaKey != null) {
                        mediaDownloadService.downloadEncryptedMedia(
                          url: replyMsg.mediaUrl!,
                          filename: replyMsg.text.isNotEmpty
                              ? replyMsg.text
                              : 'audio.m4a',
                          roomId: roomId,
                          mediaKey: replyMsg.mediaKey!,
                          mediaHash: replyMsg.mediaHash,
                        );
                      } else {
                        mediaDownloadService.downloadMedia(
                          replyMsg.mediaUrl!,
                          replyMsg.text.isNotEmpty
                              ? replyMsg.text
                              : 'audio.m4a',
                          roomId,
                        );
                      }
                    },
                  )
                : null,
            // Video widget for reply
            replyVideoWidget:
                message.replyToMessage?.type == MessageType.video &&
                    message.replyToMessage?.mediaUrl != null &&
                    message.replyToMessage!.mediaUrl!.isNotEmpty
                ? MessageVideoWidget(
                    videoUrl: message.replyToMessage!.mediaUrl!,
                    cacheHelper: cacheHelper,
                    onTapExpand: () {
                      final replyMsg = message.replyToMessage!;
                      if (replyMsg.isEncrypted && replyMsg.mediaKey != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerPage(
                              url: replyMsg.mediaUrl!,
                              roomId: roomId,
                              mediaKey: replyMsg.mediaKey,
                              mediaHash: replyMsg.mediaHash,
                            ),
                          ),
                        );
                      } else {
                        actions.onPlayReplyVideo(replyMsg);
                      }
                    },
                    onTapDownload: () {
                      final replyMsg = message.replyToMessage!;
                      if (replyMsg.isEncrypted && replyMsg.mediaKey != null) {
                        mediaDownloadService.downloadEncryptedMedia(
                          url: replyMsg.mediaUrl!,
                          filename: replyMsg.text.isNotEmpty
                              ? replyMsg.text
                              : 'video.mp4',
                          roomId: roomId,
                          mediaKey: replyMsg.mediaKey!,
                          mediaHash: replyMsg.mediaHash,
                        );
                      } else {
                        mediaDownloadService.downloadMedia(
                          replyMsg.mediaUrl!,
                          replyMsg.text.isNotEmpty
                              ? replyMsg.text
                              : 'video.mp4',
                          roomId,
                        );
                      }
                    },
                    mediaKey: message.replyToMessage!.mediaKey,
                    mediaHash: message.replyToMessage!.mediaHash,
                    mediaType: message.replyToMessage!.mediaType,
                    roomId: roomId,
                  )
                : null,
            onCopy: () => actions.onCopy(message),
            onDownload:
                (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
                ? () {
                    if (message.isEncrypted && message.mediaKey != null) {
                      mediaDownloadService.downloadEncryptedMedia(
                        url: message.mediaUrl!,
                        filename: message.text.isNotEmpty
                            ? message.text
                            : DateTimeFormatter.getDefaultFilename(message),
                        roomId: roomId,
                        mediaKey: message.mediaKey!,
                        mediaHash: message.mediaHash,
                      );
                    } else {
                      mediaDownloadService.downloadMedia(
                        message.mediaUrl!,
                        message.text.isNotEmpty
                            ? message.text
                            : DateTimeFormatter.getDefaultFilename(message),
                        roomId,
                      );
                    }
                  }
                : null,
          ),
          ),
        ),
      ],
    );
  }

  /// Format file size in bytes to human-readable string
  String? _formatFileSize(int? bytes) {
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
