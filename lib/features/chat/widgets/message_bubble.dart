import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import '_message_content_widget.dart';
import '_reply_preview_widget.dart';
import '_message_bubble_menu.dart';
import 'encryption_status_indicator.dart';

/// Reusable message bubble widget
/// Displays messages in a chat conversation with support for:
/// - Multiple message types (text, image, video, audio, doc, callLog, system)
/// - Message replies with preview
/// - Context menu with actions (reply, copy, edit, delete, download)
/// 
/// Implementation is decomposed into smaller widgets for better testability:
/// - MessageContentWidget: Handles different message types
/// - ReplyPreviewWidget: Displays reply quote
/// - MessageBubbleMenu: Context menu with actions
class MessageBubble extends StatefulWidget {
  final Message message;
  final bool fromMe;
  final String? partnerName;
  final bool isLastMessageFromUser;
  final VoidCallback? onDelete;
  final Function(Message)? onReply;
  final Function(Message, String)? onEdit;
  final Function(String)? onShowImagePreview;
  final Function(String)? onPlayAudio;
  final Widget? audioWidget;
  final Widget? videoWidget;
  final Widget? documentWidget;
  final Function(Message)? onPlayReplyAudio;
  final Function(Message)? onPlayReplyVideo;
  final Function(String)? onShowReplyImagePreview;
  final Widget? replyAudioWidget;
  final Widget? replyVideoWidget;
  final VoidCallback? onCopy;
  final VoidCallback? onDownload;
  final CacheManager? cacheManager;
  final String? roomId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.fromMe,
    required this.isLastMessageFromUser,
    this.partnerName,
    this.onDelete,
    this.onReply,
    this.onEdit,
    this.onShowImagePreview,
    this.onPlayAudio,
    this.audioWidget,
    this.videoWidget,
    this.documentWidget,
    this.onPlayReplyAudio,
    this.onPlayReplyVideo,
    this.onShowReplyImagePreview,
    this.replyAudioWidget,
    this.replyVideoWidget,
    this.onCopy,
    this.onDownload,
    this.cacheManager,
    this.roomId,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  @override
  Widget build(BuildContext context) {
    final alignment = widget.fromMe
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return RepaintBoundary(
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.fromMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (widget.fromMe && widget.onDownload != null)
              _buildDownloadButton(),
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showPopupMenu(context),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: AppSpacing.spacing8,
                  ),
                  child: _buildMessageContainer(),
                ),
              ),
            ),
            if (!widget.fromMe && widget.onDownload != null)
              _buildDownloadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing4,
        vertical: AppSpacing.spacing8,
      ),
      child: GestureDetector(
        onTap: widget.onDownload,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.download, color: AppColors.white, size: AppIconSizes.medium),
        ),
      ),
    );
  }

  Widget _buildMessageContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.fromMe ? AppColors.messageBubble : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Column(
        crossAxisAlignment: widget.fromMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message.replyToMessage != null) _buildReplyQuote(),
          _buildMessageContent(),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildReplyQuote() {
    return ReplyPreviewWidget(
      repliedMessage: widget.message.replyToMessage!,
      onShowReplyImagePreview: widget.onShowReplyImagePreview,
      onPlayReplyAudio: widget.onPlayReplyAudio,
      onPlayReplyVideo: widget.onPlayReplyVideo,
      replyAudioWidget: widget.replyAudioWidget,
      replyVideoWidget: widget.replyVideoWidget,
      cacheManager: widget.cacheManager,
    );
  }

  Widget _buildMessageContent() {
    return MessageContentWidget(
      message: widget.message,
      fromMe: widget.fromMe,
      onShowImagePreview: widget.onShowImagePreview,
      onPlayAudio: widget.onPlayAudio,
      audioWidget: widget.audioWidget,
      videoWidget: widget.videoWidget,
      documentWidget: widget.documentWidget,
      cacheManager: widget.cacheManager,
      roomId: widget.roomId,
    );
  }

  Widget _buildTimestamp() {
    final msgTime = widget.message.timestamp.toDate();

    // Show only time since date separator already shows the date
    final hour = msgTime.hour;
    final minute = msgTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = (hour % 12 == 0) ? 12 : hour % 12;
    final timeStr = '$displayHour:$minute $period';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MessageEncryptionBadge(
            isEncrypted: widget.message.isEncrypted,
            decryptionFailed: widget.message.decryptionFailed,
          ),
          Text(
            timeStr,
            style: AppTypography.captionTiny.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPopupMenu(BuildContext context) {
    final contentWidget = Column(
      crossAxisAlignment: widget.fromMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.replyToMessage != null) _buildReplyQuote(),
        _buildMessageContent(),
        _buildTimestamp(),
      ],
    );

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) => MessageBubbleMenu(
        message: widget.message,
        fromMe: widget.fromMe,
        isLastMessageFromUser: widget.isLastMessageFromUser,
        onReply: () => widget.onReply?.call(widget.message),
        onCopy: widget.onCopy,
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        messageContentWidget: contentWidget,
      ),
    );
  }
}
