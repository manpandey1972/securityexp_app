import 'package:greenhive_app/data/models/models.dart';

/// Immutable state class for ChatConversationPage
///
/// Consolidates all page state into a single object following
/// the same pattern as HomeState.
class ChatConversationState {
  // Message data
  final List<Message> messages;
  final Map<String, double> uploadingMessages;
  final Map<String, String> uploadingMessageFiles;
  final Map<String, MessageType> uploadingMessageTypes;

  // Page state
  final bool loading;
  final String? error;
  final bool servicesInitialized;

  // Room state
  final String roomId;
  final String? peerProfilePictureUrl;

  // User state
  final String? currentUserId;

  // UI state
  final bool hasText;
  final bool showAttachmentSheet;
  final Duration recordingDuration;
  final bool isRecording;
  final bool isRecordingStopped;
  final String? recordingPath;
  final Message? replyToMessage;

  const ChatConversationState({
    this.messages = const [],
    this.uploadingMessages = const {},
    this.uploadingMessageFiles = const {},
    this.uploadingMessageTypes = const {},
    this.loading = true,
    this.error,
    this.servicesInitialized = false,
    this.roomId = '',
    this.peerProfilePictureUrl,
    this.currentUserId,
    this.hasText = false,
    this.showAttachmentSheet = false,
    this.recordingDuration = Duration.zero,
    this.isRecording = false,
    this.isRecordingStopped = false,
    this.recordingPath,
    this.replyToMessage,
  });

  /// Create a copy with modified fields
  ChatConversationState copyWith({
    List<Message>? messages,
    Map<String, double>? uploadingMessages,
    Map<String, String>? uploadingMessageFiles,
    Map<String, MessageType>? uploadingMessageTypes,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? servicesInitialized,
    String? roomId,
    String? peerProfilePictureUrl,
    bool clearPeerProfilePicture = false,
    String? currentUserId,
    bool? hasText,
    bool? showAttachmentSheet,
    Duration? recordingDuration,
    bool? isRecording,
    bool? isRecordingStopped,
    String? recordingPath,
    bool clearRecordingPath = false,
    Message? replyToMessage,
    bool clearReplyToMessage = false,
  }) {
    return ChatConversationState(
      messages: messages ?? this.messages,
      uploadingMessages: uploadingMessages ?? this.uploadingMessages,
      uploadingMessageFiles:
          uploadingMessageFiles ?? this.uploadingMessageFiles,
      uploadingMessageTypes:
          uploadingMessageTypes ?? this.uploadingMessageTypes,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      servicesInitialized: servicesInitialized ?? this.servicesInitialized,
      roomId: roomId ?? this.roomId,
      peerProfilePictureUrl: clearPeerProfilePicture
          ? null
          : (peerProfilePictureUrl ?? this.peerProfilePictureUrl),
      currentUserId: currentUserId ?? this.currentUserId,
      hasText: hasText ?? this.hasText,
      showAttachmentSheet: showAttachmentSheet ?? this.showAttachmentSheet,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      isRecording: isRecording ?? this.isRecording,
      isRecordingStopped: isRecordingStopped ?? this.isRecordingStopped,
      recordingPath: clearRecordingPath ? null : (recordingPath ?? this.recordingPath),
      replyToMessage: clearReplyToMessage
          ? null
          : (replyToMessage ?? this.replyToMessage),
    );
  }
}
