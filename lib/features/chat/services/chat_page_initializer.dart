import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/models/chat_message_actions.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/services/media_download_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_scroll_handler.dart';
import 'package:securityexperts_app/features/chat/services/chat_stream_service.dart';
import 'package:securityexperts_app/features/chat/services/reply_management_service.dart';
import 'package:securityexperts_app/features/chat/services/audio_recording_manager.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_cache_helper.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_handler.dart';
import 'package:securityexperts_app/features/chat/services/message_send_handler.dart';
import 'package:securityexperts_app/features/chat/services/chat_recording_handler.dart';
import 'package:securityexperts_app/features/chat/utils/chat_navigation_helper.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Result container for initialized chat page services and state
class ChatPageInitializationResult {
  // Services
  final ChatMediaCacheHelper mediaCacheHelper;
  final ReplyManagementService replyManagementService;
  final AudioRecordingManager audioRecordingManager;
  final ChatStreamService chatStreamService;
  final ChatScrollHandler scrollHandler;
  final ChatMediaHandler mediaHandler;
  final MessageSendHandler messageSendHandler;
  final ChatRecordingHandler recordingHandler;

  // Message actions
  final ChatMessageActions messageActions;

  // Value notifiers
  final ValueNotifier<bool> hasTextNotifier;
  final ValueNotifier<bool> showAttachmentSheetNotifier;
  final ValueNotifier<Duration> recordingDuration;

  ChatPageInitializationResult({
    required this.mediaCacheHelper,
    required this.replyManagementService,
    required this.audioRecordingManager,
    required this.chatStreamService,
    required this.scrollHandler,
    required this.mediaHandler,
    required this.messageSendHandler,
    required this.recordingHandler,
    required this.messageActions,
    required this.hasTextNotifier,
    required this.showAttachmentSheetNotifier,
    required this.recordingDuration,
  });
}

/// Handles initialization of all chat page services and dependencies
class ChatPageInitializer {
  /// Initializes all services, handlers, and state for the chat conversation page
  static ChatPageInitializationResult initialize({
    required BuildContext context,
    required String roomId,
    required ChatMessageRepository messageRepository,
    required MediaCacheService mediaCacheService,
    required MediaDownloadService mediaDownloadService,
    required ItemScrollController itemScrollController,
    required ItemPositionsListener itemPositionsListener,
    required List<Message> messages,
    required VoidCallback onStateChanged,
    required void Function(String?) onErrorChanged,
    required void Function(bool) onLoadingChanged,
    required void Function(Duration) onRecordingDurationChanged,
    required void Function(Message message) onDeleteMessage,
    required void Function(Message message, String originalText) onEditMessage,
    required void Function(Message message) onCopyMessage,
  }) {
    final log = sl<AppLogger>();
    const tag = 'ChatPageInitializer';
    log.debug('Starting initialization', tag: tag);

    // Initialize value notifiers
    final hasTextNotifier = ValueNotifier<bool>(false);
    final showAttachmentSheetNotifier = ValueNotifier<bool>(false);
    final recordingDuration = ValueNotifier<Duration>(Duration.zero);

    // Initialize media cache helper
    final mediaCacheHelper = ChatMediaCacheHelper(
      mediaCacheService: mediaCacheService,
      roomId: roomId,
    );

    // Initialize reply management service
    final replyManagementService = ReplyManagementService(
      onReplyChanged: (message) => onStateChanged(),
    );

    // Initialize audio recording manager
    final audioRecordingManager = AudioRecordingManager(
      onRecordingStateChanged: (isRecording) => onStateChanged(),
      onRecordingDurationChanged: (duration) {
        recordingDuration.value = duration;
        onRecordingDurationChanged(duration);
      },
      onError: (error) => SnackbarService.show(error),
    );

    // Initialize chat stream service
    final chatStreamService = ChatStreamService(roomId: roomId);
    chatStreamService.onMessagesUpdated = (newMessages) {
      log.debug(
        'onMessagesUpdated called with ${newMessages.length} messages',
        tag: tag,
      );
      messages.clear();
      messages.addAll(newMessages);
      onLoadingChanged(false);
      onErrorChanged(null);
      onStateChanged();
      log.debug(
        'setState completed for ${newMessages.length} messages',
        tag: tag,
      );
    };
    chatStreamService.onError = (error) {
      onErrorChanged(error);
      onStateChanged();
    };

    // Initialize scroll handler
    final scrollHandler = ChatScrollHandler(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      messageRepository: messageRepository,
      roomId: roomId,
      onLoadingStateChanged: (isLoading) {
        // Pagination state updates handled internally
      },
      onMessagesLoaded: (newMessages) {
        messages.insertAll(0, newMessages);
        onStateChanged();
      },
      onNoMoreMessages: () {
        // No more messages to load
      },
    );

    // Initialize media handler
    final mediaHandler = ChatMediaHandler(
      roomId: roomId,
      getReplyToMessage: () => replyManagementService.replyingTo,
      clearReply: () => replyManagementService.clearReply(),
    );

    // Initialize message send handler
    final messageSendHandler = MessageSendHandler(
      messageRepository: messageRepository,
      roomId: roomId,
      itemScrollController: itemScrollController,
      getReplyToMessage: () => replyManagementService.replyingTo,
      clearReply: () => replyManagementService.clearReply(),
    );

    // Initialize recording handler
    final recordingHandler = ChatRecordingHandler(
      audioRecordingManager: audioRecordingManager,
      onRecordingComplete: (audioFile) async {
        // Audio will be sent when user clicks Send in preview
        await mediaHandler.handleAudioFile(audioFile: audioFile);
      },
    );

    // Initialize message actions
    final messageActions = ChatMessageActions(
      onDelete: onDeleteMessage,
      onReply: (message) {
        replyManagementService.setReplyingTo(message);
        onStateChanged();
      },
      onEdit: onEditMessage,
      onShowImagePreview: (url) =>
          ChatNavigationHelper(context, roomId: roomId).showImagePreview(url),
      onPlayAudio: (url) {
        // Play audio callback (currently no-op, handled by inline player)
      },
      onPlayVideo: (url) =>
          ChatNavigationHelper(context, roomId: roomId).openVideoPlayer(url),
      onPlayReplyAudio: (message) {
        // Play reply audio callback (currently no-op)
      },
      onPlayReplyVideo: (message) {
        if (message.mediaUrl != null) {
          ChatNavigationHelper(
            context,
            roomId: roomId,
          ).openVideoPlayer(
            message.mediaUrl!,
            mediaKey: message.mediaKey,
            mediaHash: message.mediaHash,
          );
        }
      },
      onShowReplyImagePreview: (url) =>
          ChatNavigationHelper(context, roomId: roomId).showImagePreview(url),
      onCopy: onCopyMessage,
      onDownload: (mediaUrl, filename, roomId) {
        mediaDownloadService.downloadMedia(mediaUrl, filename, roomId);
      },
    );

    log.debug('Initialization complete', tag: tag);

    return ChatPageInitializationResult(
      mediaCacheHelper: mediaCacheHelper,
      replyManagementService: replyManagementService,
      audioRecordingManager: audioRecordingManager,
      chatStreamService: chatStreamService,
      scrollHandler: scrollHandler,
      mediaHandler: mediaHandler,
      messageSendHandler: messageSendHandler,
      recordingHandler: recordingHandler,
      messageActions: messageActions,
      hasTextNotifier: hasTextNotifier,
      showAttachmentSheetNotifier: showAttachmentSheetNotifier,
      recordingDuration: recordingDuration,
    );
  }
}
