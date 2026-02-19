// === IMPORTS ===
// Flutter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// External packages
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

// App - Core
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

// App - Models
import 'package:securityexperts_app/data/models/models.dart';

// App - ViewModels & State
import 'package:securityexperts_app/features/chat/presentation/view_models/chat_conversation_view_model.dart';
import 'package:securityexperts_app/features/chat/presentation/state/chat_conversation_state.dart';

// App - Services
import 'package:securityexperts_app/features/calling/services/call_coordinator.dart';

// App - Widgets
import 'package:securityexperts_app/features/chat/widgets/uploading_message.dart';
import 'package:securityexperts_app/features/chat/widgets/scroll_to_bottom_button.dart';
import 'package:securityexperts_app/features/chat/widgets/chat_app_bar_new.dart';
import 'package:securityexperts_app/features/chat/widgets/chat_input_widget.dart';
import 'package:securityexperts_app/features/chat/widgets/chat_message_list_item.dart';
import 'package:securityexperts_app/features/chat/widgets/audio_recording_overlay.dart';
import '../widgets/attachment_menu_sheet.dart';

// App - Utils & UI
import 'package:securityexperts_app/features/chat/utils/chat_message_helper.dart';
import 'package:securityexperts_app/features/chat/utils/chat_utils.dart';
import 'media_manager_page.dart' show CachedMediaPage;
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/constants.dart' show AppStrings;

class ChatConversationPage extends StatelessWidget {
  final String? roomId;
  final String? userName;
  final String? partnerName;
  final String? partnerId;
  final String? peerProfilePictureUrl;

  const ChatConversationPage({
    super.key,
    this.roomId,
    this.partnerName,
    this.partnerId,
    this.userName,
    this.peerProfilePictureUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatConversationViewModel>(
      create: (_) => sl<ChatConversationViewModel>(),
      child: _ChatConversationPageContent(
        roomId: roomId,
        partnerName: partnerName,
        partnerId: partnerId,
        peerProfilePictureUrl: peerProfilePictureUrl,
      ),
    );
  }
}

class _ChatConversationPageContent extends StatefulWidget {
  final String? roomId;
  final String? partnerName;
  final String? partnerId;
  final String? peerProfilePictureUrl;

  const _ChatConversationPageContent({
    required this.roomId,
    required this.partnerName,
    required this.partnerId,
    required this.peerProfilePictureUrl,
  });

  @override
  State<_ChatConversationPageContent> createState() =>
      _ChatConversationPageContentState();
}

class _ChatConversationPageContentState
    extends State<_ChatConversationPageContent> {
  static const String _tag = 'ChatConversationPage';
  final AppLogger _log = sl<AppLogger>();

  @override
  void initState() {
    super.initState();
    // Initialize room after first frame when context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = Provider.of<ChatConversationViewModel>(
          context,
          listen: false,
        );
        viewModel.initializeRoom(
          context: context,
          initialRoomId: widget.roomId,
          partnerId: widget.partnerId,
          peerProfilePictureUrl: widget.peerProfilePictureUrl,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatConversationViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        final title = widget.partnerName ?? widget.partnerId ?? 'Chat';

        return Scaffold(
          appBar: _buildAppBar(context, title, viewModel, state),
          body: Stack(
            children: [
              _buildBody(context, viewModel, state),
              // Audio recording overlay (recording or preview mode)
              if (state.isRecording || state.isRecordingStopped)
                AudioRecordingOverlay(
                  duration: state.recordingDuration,
                  isRecording: state.isRecording,
                  recordingPath: state.recordingPath,
                  onDiscard: () => viewModel.discardRecording(),
                  onSend: () => viewModel.sendRecording(),
                  onStop: () => viewModel.stopRecording(),
                ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String title,
    ChatConversationViewModel viewModel,
    ChatConversationState state,
  ) {
    return ChatAppBar(
      title: title,
      profilePictureUrl: state.peerProfilePictureUrl,
      onAudioCall: () => _startCall(context, false),
      onVideoCall: () => _startCall(context, true),
      onMediaManager: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CachedMediaPage(
              roomId: state.roomId,
              mediaCacheService: viewModel.mediaCacheService,
              prefetch: () async => await viewModel.mediaCacheHelper
                  ?.prefetchAllMedia(state.messages),
            ),
          ),
        );
      },
      onClearChat: () => _showClearChatDialog(context, viewModel),
      onDeleteChat: () => _showDeleteChatDialog(context, viewModel),
    );
  }

  void _showClearChatDialog(
    BuildContext context,
    ChatConversationViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(AppStrings.clearChat),
        content: const Text(
          'This will delete all messages in this conversation. This action cannot be undone.',
        ),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButtonVariants.dialogAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await viewModel.clearChat();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? AppStrings.chatCleared : AppStrings.failedToClearChat,
                    ),
                  ),
                );
              }
            },
            label: 'Clear',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog(
    BuildContext context,
    ChatConversationViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Chat'),
        content: const Text(
          'This will permanently delete this conversation and all its messages. This action cannot be undone.',
        ),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButtonVariants.dialogAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await viewModel.deleteChat();
              if (context.mounted) {
                if (success) {
                  // Navigate back since the chat no longer exists
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text(AppStrings.chatDeleted)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppStrings.failedToDeleteChat)),
                  );
                }
              }
            },
            label: 'Delete',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ChatConversationViewModel viewModel,
    ChatConversationState state,
  ) {
    return Column(
      children: [
        Expanded(child: _buildMessageListOrState(context, viewModel, state)),
        _buildInputWidget(context, viewModel, state),
      ],
    );
  }

  Widget _buildMessageListOrState(
    BuildContext context,
    ChatConversationViewModel viewModel,
    ChatConversationState state,
  ) {
    // Show loading if services aren't initialized yet
    if (!state.servicesInitialized || state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading messages: ${state.error}'),
          ),
        ],
      );
    }

    return _buildMessageList(context, viewModel, state);
  }

  Widget _buildMessageList(
    BuildContext context,
    ChatConversationViewModel viewModel,
    ChatConversationState state,
  ) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: ScrollablePositionedList.builder(
            itemScrollController: viewModel.itemScrollController,
            itemPositionsListener: viewModel.itemPositionsListener,
            physics: viewModel.scrollHandler?.isLoadingMore ?? false
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: state.messages.length + state.uploadingMessages.length,
            itemBuilder: (context, index) =>
                _buildMessageItem(context, viewModel, state, index),
          ),
        ),
        ScrollToBottomButton(
          itemPositionsListener: viewModel.itemPositionsListener,
          itemScrollController: viewModel.itemScrollController,
        ),
      ],
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    ChatConversationViewModel viewModel,
    ChatConversationState state,
    int index,
  ) {
    // Show uploading messages first (at bottom since reversed)
    if (index < state.uploadingMessages.length) {
      return _buildUploadingMessageItem(state, index);
    }

    // Show regular messages
    final messageIndex = index - state.uploadingMessages.length;
    final reversedIndex = state.messages.length - 1 - messageIndex;
    final m = state.messages[reversedIndex];
    final previousMessage = reversedIndex > 0
        ? state.messages[reversedIndex - 1]
        : null;
    final fromMe = m.senderId == state.currentUserId;

    return ChatMessageListItem(
      message: m,
      previousMessage: previousMessage,
      fromMe: fromMe,
      isLastMessageFromUser:
          fromMe && _isLastMessageFromUser(m, state.messages),
      partnerName: widget.partnerName,
      actions: viewModel.messageActions!,
      cacheHelper: viewModel.mediaCacheHelper!,
      mediaDownloadService: viewModel.mediaDownloadService,
      scrollHandler: viewModel.scrollHandler!,
      allMessages: state.messages,
      roomId: state.roomId,
      currentUserId: state.currentUserId ?? '',
    );
  }

  Widget _buildUploadingMessageItem(ChatConversationState state, int index) {
    final tempId = state.uploadingMessages.keys.elementAt(index);
    final progress = state.uploadingMessages[tempId]!;
    final filename = state.uploadingMessageFiles[tempId]!;
    final type = state.uploadingMessageTypes[tempId]!;

    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(ChatConstants.chatMessagePadding),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(ChatConstants.chatBorderRadius),
        ),
        child: UploadingMessageWidget(
          filename: filename,
          type: type,
          progress: progress,
        ),
      ),
    );
  }

  Widget _buildInputWidget(
    BuildContext context,
    ChatConversationViewModel viewModel,
    ChatConversationState state,
  ) {
    // Don't show input if services aren't initialized
    if (!state.servicesInitialized) {
      return const SizedBox.shrink();
    }

    return ChatInputWidget(
      controller: viewModel.textController,
      hasTextNotifier: ValueNotifier<bool>(state.hasText),
      showAttachmentSheetNotifier: ValueNotifier<bool>(
        state.showAttachmentSheet,
      ),
      recordingDuration: ValueNotifier<Duration>(state.recordingDuration),
      onAttachmentTap: () => _showAttachmentBottomSheet(
        context,
        viewModel,
      ),
      onSendTap: () => viewModel.sendMessage(),
      onStartRecording: () => viewModel.startRecording(),
      onStopRecording: () => viewModel.stopRecording(),
      onCameraCapture: (filePath, bytes, fileName) =>
          viewModel.handleCameraCapture(context, filePath, bytes, fileName),
      isRecording: state.isRecording,
      isRecordingStopped: state.isRecordingStopped,
      replyPreviewBar: _buildReplyPreviewBar(context, viewModel),
      attachmentSheetBuilder: null, // No longer needed as widget
    );
  }

  void _showAttachmentBottomSheet(
    BuildContext context,
    ChatConversationViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.black.withValues(alpha: 0.26),
      builder: (ctx) => AttachmentMenuSheet(
        showSheet: true,
        onPhotosTap: () {
          Navigator.pop(ctx);
          viewModel.handleAttachMedia(context);
        },
        onDocumentTap: () {
          Navigator.pop(ctx);
          viewModel.handleAttachFile(context);
        },
      ),
    );
  }

  // ...existing code...

  Widget _buildReplyPreviewBar(
    BuildContext context,
    ChatConversationViewModel viewModel,
  ) {
    return viewModel.replyManagementService?.buildReplyPreviewBar(
          context,
          onClear: () => viewModel.clearReply(),
          isRecording: viewModel.state.isRecording,
        ) ??
        const SizedBox.shrink();
  }

  bool _isLastMessageFromUser(Message message, List<Message> messages) {
    return ChatMessageHelper.isLastMessageFromUser(message, messages);
  }

  void _startCall(BuildContext context, bool isVideo) async {
    _log.debug(
      '_startCall called - isVideo: $isVideo, partnerId: ${widget.partnerId}',
      tag: _tag,
    );
    await CallCoordinator.startCall(
      context: context,
      partnerId: widget.partnerId ?? '',
      partnerName: widget.partnerName ?? 'User',
      isVideo: isVideo,
    );
    _log.debug('_startCall completed', tag: _tag);
  }
}
