import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/models/chat_message_actions.dart';
import 'package:securityexperts_app/features/chat/presentation/state/chat_conversation_state.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/shared/services/upload_manager.dart';
import 'package:securityexperts_app/core/analytics/chat_analytics.dart';

// Services
import 'package:securityexperts_app/features/chat/services/unread_messages_service.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_scroll_handler.dart';
import 'package:securityexperts_app/shared/services/media_download_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_stream_service.dart';
import 'package:securityexperts_app/features/chat/services/reply_management_service.dart';
import 'package:securityexperts_app/features/chat/services/audio_recording_manager.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_cache_helper.dart';
import 'package:securityexperts_app/features/chat/services/chat_page_service.dart';
import 'package:securityexperts_app/features/chat/services/chat_page_initializer.dart';
import 'package:securityexperts_app/features/chat/utils/chat_dialog_helper.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_handler.dart';
import 'package:securityexperts_app/features/chat/services/message_send_handler.dart';
import 'package:securityexperts_app/features/chat/services/chat_recording_handler.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/features/calling/services/call_logger.dart';

/// ViewModel for ChatConversationPage
///
/// Thin facade that coordinates specialised handler classes.  Business logic
/// lives in the handlers; this ViewModel exposes a unified API to the UI.
///
/// **Handler responsibilities**:
/// | Handler                | Domain                                |
/// |------------------------|---------------------------------------|
/// | [ChatMediaHandler]     | File / image / video attachment        |
/// | [MessageSendHandler]   | Composing & sending messages           |
/// | [ChatRecordingHandler] | Audio recording lifecycle              |
/// | [ChatScrollHandler]    | Infinite-scroll & jump-to-bottom       |
/// | [ChatMediaCacheHelper] | Per-room media cache warm-up           |
/// | [ChatPageService]      | High-level operations (delete, edit)   |
/// | [ChatStreamService]    | Real-time Firestore message stream     |
/// | [ReplyManagementService]| Reply-to state management             |
/// | [ChatPageInitializer]  | Room-level initialisation              |
/// | [ChatMessageActions]   | Long-press / context-menu actions      |
class ChatConversationViewModel extends ChangeNotifier {
  // Logger
  final CallLogger _logger;

  // Repositories
  final ChatRoomRepository _roomRepository;
  final ChatMessageRepository _messageRepository;
  
  // Services
  final UnreadMessagesService _unreadMessagesService;
  final MediaDownloadService _mediaDownloadService;
  final MediaCacheService _mediaCacheService;
  final ChatPageService _chatPageService;
  final UploadManager _uploadManager;

  // Nullable services (initialized after room is ready)
  ChatStreamService? _chatStreamService;
  ReplyManagementService? _replyManagementService;
  AudioRecordingManager? _audioRecordingManager;
  ChatMediaCacheHelper? _mediaCacheHelper;
  ChatScrollHandler? _scrollHandler;
  ChatMediaHandler? _mediaHandler;
  MessageSendHandler? _messageSendHandler;
  ChatRecordingHandler? _recordingHandler;
  ChatMessageActions? _messageActions;

  // Controllers
  final TextEditingController textController = TextEditingController();
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  // State
  ChatConversationState _state = const ChatConversationState();
  ChatConversationState get state => _state;

  // Scroll listener callback
  VoidCallback? _scrollListenerCallback;

  ChatConversationViewModel({
    required ChatRoomRepository roomRepository,
    required ChatMessageRepository messageRepository,
    required UnreadMessagesService unreadMessagesService,
    required MediaDownloadService mediaDownloadService,
    required MediaCacheService mediaCacheService,
    required ChatPageService chatPageService,
    UploadManager? uploadManager,
    CallLogger? logger,
  }) : _roomRepository = roomRepository,
       _messageRepository = messageRepository,
       _unreadMessagesService = unreadMessagesService,
       _mediaDownloadService = mediaDownloadService,
       _mediaCacheService = mediaCacheService,
       _chatPageService = chatPageService,
       _uploadManager = uploadManager ?? sl<UploadManager>(),
       _logger = logger ?? DebugCallLogger() {
    // Setup text controller listener
    textController.addListener(_onTextChanged);
    // Listen to upload manager for progress updates
    _uploadManager.addListener(_onUploadStateChanged);
  }

  // Getters for services (for UI access)
  ReplyManagementService? get replyManagementService => _replyManagementService;
  AudioRecordingManager? get audioRecordingManager => _audioRecordingManager;
  ChatMediaCacheHelper? get mediaCacheHelper => _mediaCacheHelper;
  ChatMessageActions? get messageActions => _messageActions;
  MediaDownloadService get mediaDownloadService => _mediaDownloadService;
  MediaCacheService get mediaCacheService => _mediaCacheService;
  ChatScrollHandler? get scrollHandler => _scrollHandler;

  void _onTextChanged() {
    _updateState(_state.copyWith(hasText: textController.text.isNotEmpty));
  }

  /// Called when upload manager state changes
  void _onUploadStateChanged() {
    if (_state.roomId.isEmpty) return;
    
    // Get uploads for this room
    final roomUploads = _uploadManager.getActiveUploadsForRoom(_state.roomId);
    
    // Convert to maps for state
    final uploadingMessages = <String, double>{};
    final uploadingMessageFiles = <String, String>{};
    final uploadingMessageTypes = <String, MessageType>{};
    
    for (final upload in roomUploads) {
      uploadingMessages[upload.id] = upload.progress;
      uploadingMessageFiles[upload.id] = upload.filename;
      uploadingMessageTypes[upload.id] = upload.type;
    }
    
    _updateState(_state.copyWith(
      uploadingMessages: uploadingMessages,
      uploadingMessageFiles: uploadingMessageFiles,
      uploadingMessageTypes: uploadingMessageTypes,
    ));
  }

  void _updateState(ChatConversationState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Initialize the chat room
  Future<void> initializeRoom({
    required BuildContext context,
    required String? initialRoomId,
    required String? partnerId,
    String? peerProfilePictureUrl,
  }) async {
    String roomId = initialRoomId ?? '';

    // Get current user ID
    final user = sl<FirebaseAuth>().currentUser;
    final currentUserId = user?.uid;

    // Update state with currentUserId immediately
    _updateState(_state.copyWith(currentUserId: currentUserId));

    // If roomId is not provided but partnerId is, fetch from Firestore
    if (roomId.isEmpty && partnerId != null && partnerId.isNotEmpty) {
      _logger.debug('Fetching room for partner: $partnerId');
      await ErrorHandler.handle<void>(
        operation: () async {
          if (currentUserId == null) {
            _logger.warning('No authenticated user');
            return;
          }

          roomId = await _roomRepository.getOrCreateRoom(currentUserId, partnerId);
          _logger.info('Got roomId: $roomId');

          _updateState(
            _state.copyWith(
              roomId: roomId,
              peerProfilePictureUrl: peerProfilePictureUrl,
            ),
          );
        },
        fallback: null,
        onError: (error) {
          _logger.error('Failed to initialize room', error);
          _updateState(
            _state.copyWith(
              error: 'Failed to initialize room: $error',
            ),
          );
        },
      );
    } else {
      _logger.debug('Using provided roomId: $roomId');
      _updateState(
        _state.copyWith(
          roomId: roomId,
          peerProfilePictureUrl: peerProfilePictureUrl,
        ),
      );
    }

    // Initialize services if we have a valid room
    if (_state.roomId.isNotEmpty) {
      // Track conversation opened
      ChatAnalytics.conversationOpened(
        messageCount: _state.messages.length,
      );

      // Update presence to indicate user is in this chat room
      // This prevents push notifications for this room while viewing it
      sl<UserPresenceService>().enterChatRoom(_state.roomId);
      
      // ignore: use_build_context_synchronously
      await _initializeChatServices(context);
      _subscribeToMessages();
    } else {
      _updateState(_state.copyWith(loading: false));
    }
  }

  // Shared mutable state for chat initializer - avoids repeated copying
  late final List<Message> _sharedMessages;
  bool _sharedStateInitialized = false;

  Future<void> _initializeChatServices(BuildContext context) async {
    _logger.debug('Initializing chat services with roomId: ${_state.roomId}');

    // Initialize shared mutable state only once to avoid repeated copying
    if (!_sharedStateInitialized) {
      _sharedMessages = List<Message>.from(_state.messages);
      _sharedStateInitialized = true;
    }

    // Initialize all chat page services using initializer
    final initResult = ChatPageInitializer.initialize(
      context: context,
      roomId: _state.roomId,
      messageRepository: _messageRepository,
      mediaCacheService: _mediaCacheService,
      mediaDownloadService: _mediaDownloadService,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      messages: _sharedMessages,
      onStateChanged: () {
        // Update state with reference to shared lists - no copying needed
        // The lists are already updated in place by the initializer
        _updateState(_state.copyWith(messages: _sharedMessages));
      },
      onErrorChanged: (error) {
        _updateState(_state.copyWith(error: error));
      },
      onLoadingChanged: (loading) {
        _updateState(_state.copyWith(loading: loading));
      },
      onRecordingDurationChanged: (duration) {
        _updateState(_state.copyWith(recordingDuration: duration));
      },
      onDeleteMessage: (message) {
        // This is called by message actions, context is stored in ChatMessageActions
        deleteMessage(message, context);
      },
      onEditMessage: (message, originalText) {
        // This is called by message actions, context is stored in ChatMessageActions
        editMessage(message, originalText, context);
      },
      onCopyMessage: copyMessageToClipboard,
    );

    // Assign initialized services
    _mediaCacheHelper = initResult.mediaCacheHelper;
    _replyManagementService = initResult.replyManagementService;
    _audioRecordingManager = initResult.audioRecordingManager;
    _chatStreamService = initResult.chatStreamService;
    _scrollHandler = initResult.scrollHandler;
    _mediaHandler = initResult.mediaHandler;
    _messageSendHandler = initResult.messageSendHandler;
    _recordingHandler = initResult.recordingHandler;
    _messageActions = initResult.messageActions;

    // Setup scroll listener
    _scrollListenerCallback = () {
      _scrollHandler?.handleScroll(_sharedMessages);
    };
    itemPositionsListener.itemPositions.addListener(_scrollListenerCallback!);

    _updateState(_state.copyWith(
      servicesInitialized: true,
      isE2eeEnabled: _messageRepository.isE2eeEnabled,
    ));
  }

  void _subscribeToMessages() {
    if (_state.roomId.isEmpty) {
      _updateState(_state.copyWith(loading: false, messages: []));
      return;
    }

    // Start listening to messages
    _chatStreamService?.startListening();
  }

  /// Send a text message
  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    // Track message sent
    ChatAnalytics.messageSent(
      messageType: 'text',
      hasReply: _state.replyToMessage != null,
      textLength: text.length,
    );

    await _messageSendHandler?.sendMessage(
      text: text,
      onSuccess: () {
        textController.clear();
        _updateState(_state.copyWith(hasText: false));
      },
    );
  }

  /// Delete a message
  Future<void> deleteMessage(Message message, BuildContext context) async {
    // Track message deletion
    ChatAnalytics.messageDeleted(messageType: message.type.name);

    // Remove from local state immediately
    final updatedMessages = List<Message>.from(_state.messages);
    updatedMessages.removeWhere((m) => m.id == message.id);
    _updateState(_state.copyWith(messages: updatedMessages));

    // Delete from backend
    await _chatPageService.deleteMessage(
      roomId: _state.roomId,
      messageId: message.id,
    );
  }

  /// Edit a message
  Future<void> editMessage(
    Message message,
    String originalText,
    BuildContext context,
  ) async {
    final editedText = await ChatDialogHelper.showEditMessageDialog(
      context,
      message,
      originalText,
      _messageRepository,
      _state.roomId,
    );
    
    if (editedText != null && editedText != originalText) {
      // Update local state immediately
      final updatedMessages = _state.messages.map((m) {
        return m.id == message.id ? m.copyWith(text: editedText) : m;
      }).toList();
      _updateState(_state.copyWith(messages: updatedMessages));
    }
  }

  /// Copy message to clipboard
  void copyMessageToClipboard(Message message) {
    // This will be handled by ChatMessageHelper in the UI layer
  }

  /// Clear reply
  void clearReply() {
    _replyManagementService?.clearReply();
    _updateState(_state.copyWith(clearReplyToMessage: true));
  }

  /// Toggle attachment sheet
  void toggleAttachmentSheet() {
    _updateState(
      _state.copyWith(showAttachmentSheet: !_state.showAttachmentSheet),
    );
  }

  /// Handle file attachment
  /// Handle file attachment (supports multiple selection)
  Future<void> handleAttachFile(BuildContext context) async {
    toggleAttachmentSheet();
    await _mediaHandler?.handleAttachFile(context: context);
  }

  /// Handle media attachment (supports multiple selection)
  Future<void> handleAttachMedia(BuildContext context) async {
    toggleAttachmentSheet();
    await _mediaHandler?.handleAttachMedia(context: context);
  }

  /// Handle camera capture
  Future<void> handleCameraCapture(
    BuildContext context,
    String? filePath,
    List<int> bytes,
    String fileName,
  ) async {
    await _mediaHandler?.handleCameraCapture(
      context: context,
      filePath: filePath,
      bytes: bytes,
      filename: fileName,
    );
  }

  /// Start recording
  Future<void> startRecording() async {
    await _recordingHandler?.startRecording();
    _updateState(_state.copyWith(isRecording: true, isRecordingStopped: false));
  }

  /// Stop recording and show in preview mode
  Future<void> stopRecording() async {
    _logger.debug('stopRecording called');
    // Stop recording to finalize file for playback
    final recordingFile = await _recordingHandler?.stopRecordingForPreview();
    _logger.debug('stopRecording: file=${recordingFile?.path}');
    _updateState(_state.copyWith(
      isRecording: false,
      isRecordingStopped: true,
      recordingPath: recordingFile?.path,
    ));
  }

  /// Send the recorded audio
  Future<void> sendRecording() async {
    _logger.debug('sendRecording: path=${_state.recordingPath}');
    if (_state.recordingPath != null) {
      final file = File(_state.recordingPath!);
      final exists = file.existsSync();
      _logger.debug('sendRecording: file exists=$exists');
      if (exists) {
        await _mediaHandler?.handleAudioFile(audioFile: file);
        // NOTE: Do NOT delete the recording file here.
        // The upload manager fires the upload in the background (not awaited),
        // so the file must remain on disk until Firebase Storage finishes reading it.
        // The file is in the temp/Caches directory, so iOS/Android will clean it up.
      } else {
        _logger.error('sendRecording: recording file not found at ${_state.recordingPath}', null);
      }
    } else {
      _logger.warning('sendRecording: no recording path in state');
    }
    _updateState(_state.copyWith(
      isRecordingStopped: false,
      recordingDuration: Duration.zero,
      clearRecordingPath: true,
    ));
  }

  /// Discard recording without sending
  Future<void> discardRecording() async {
    await _recordingHandler?.cancelRecording();
    _updateState(_state.copyWith(
      isRecording: false,
      isRecordingStopped: false,
      recordingDuration: Duration.zero,
      clearRecordingPath: true,
    ));
  }

  /// Mark room as read when leaving
  Future<void> markRoomAsRead() async {
    if (_state.roomId.isNotEmpty) {
      await ErrorHandler.handle<void>(
        operation: () => _unreadMessagesService.markRoomAsRead(_state.roomId),
        fallback: null,
        onError: (e) => _logger.warning('Error marking room as read: $e'),
      );
    }
  }

  /// Clear all messages in the current chat room.
  /// Returns true if successful.
  Future<bool> clearChat() async {
    if (_state.roomId.isEmpty) {
      _logger.warning('Cannot clear chat: no room ID');
      return false;
    }

    _logger.info('Clearing chat for room: ${_state.roomId}');

    final result = await _roomRepository.clearChat(_state.roomId);

    if (result) {
      // Clear local messages immediately for responsive UI
      _updateState(_state.copyWith(messages: []));
      _logger.info('Chat cleared successfully');
    } else {
      _logger.warning('Failed to clear chat');
    }

    return result;
  }

  /// Delete the current chat room and all its messages.
  /// Returns true if successful.
  Future<bool> deleteChat() async {
    if (_state.roomId.isEmpty) {
      _logger.warning('Cannot delete chat: no room ID');
      return false;
    }

    _logger.info('Deleting chat room: ${_state.roomId}');

    try {
      await _roomRepository.deleteRoom(_state.roomId);
      _logger.info('Chat room deleted successfully');
      return true;
    } catch (e) {
      _logger.warning('Failed to delete chat room: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _logger.debug('Disposing ChatConversationViewModel');
    
    // Update presence to indicate user left the chat room
    sl<UserPresenceService>().leaveChatRoom();
    
    textController.dispose();
    if (_scrollListenerCallback != null) {
      itemPositionsListener.itemPositions.removeListener(
        _scrollListenerCallback!,
      );
    }
    _uploadManager.removeListener(_onUploadStateChanged);
    _mediaCacheHelper?.clearCache();
    _chatStreamService?.dispose();
    _replyManagementService?.dispose();
    _audioRecordingManager?.dispose();
    markRoomAsRead();
    super.dispose();
  }
}
