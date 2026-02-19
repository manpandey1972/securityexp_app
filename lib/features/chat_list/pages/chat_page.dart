// === IMPORTS ===
// Flutter
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// External packages
import 'package:securityexperts_app/providers/auth_provider.dart';

// Internal - Models
import 'package:securityexperts_app/data/models/models.dart' as models;

// Internal - Pages
import 'package:securityexperts_app/features/chat/pages/chat_conversation_page.dart';

// Internal - Services
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';

// Internal - Widgets
import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/shared/widgets/shimmer_loading.dart';
import 'package:securityexperts_app/shared/widgets/error_state_widget.dart';
import 'package:securityexperts_app/shared/widgets/empty_state_widget.dart';

// Internal - Theme
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';

// Internal - ViewModels & State
import 'package:securityexperts_app/features/chat_list/presentation/view_models/chat_list_view_model.dart';
import 'package:securityexperts_app/features/chat_list/presentation/state/chat_list_state.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';

/// Chat list page displaying all active conversations
///
/// Uses Provider+ChangeNotifier pattern with ChatListViewModel for state management.
class ChatPage extends StatelessWidget {
  final VoidCallback? onLoadRequested;
  final void Function(VoidCallback)? onRegisterLoadCallback;

  const ChatPage({
    super.key,
    this.onLoadRequested,
    this.onRegisterLoadCallback,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatListViewModel>(
      create: (_) {
        final viewModel = sl<ChatListViewModel>();
        // Set up load callback
        viewModel.setLoadCallback(() => viewModel.loadRooms());
        // Initialize with coordination callbacks
        viewModel.initialize(
          onLoadRequested: onLoadRequested,
          onRegisterLoadCallback: onRegisterLoadCallback,
        );
        return viewModel;
      },
      child: const _ChatPageContent(),
    );
  }
}

class _ChatPageContent extends StatelessWidget {
  const _ChatPageContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatListViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;

        return RefreshIndicator(
          onRefresh: viewModel.loadRooms,
          child: _buildContent(context, viewModel, state),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ChatListViewModel viewModel,
    ChatListState state,
  ) {
    if (state.loading) {
      return ShimmerLoading.list(
        itemCount: 8,
        itemBuilder: () => ShimmerLoading.chatListItem(),
      );
    }

    if (state.error != null) {
      return ListView(
        children: [
          SizedBox(
            height: 400,
            child: ErrorStateWidget.server(
              title: 'Failed to load chats',
              message: state.error,
              onRetry: viewModel.loadRooms,
            ),
          ),
        ],
      );
    }

    if (state.rooms.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 400,
            child: EmptyStateWidget.list(
              title: 'No chats yet',
              description: 'Start a conversation to see it here',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: state.rooms.length,
      itemBuilder: (context, index) {
        final room = state.rooms[index];
        return _buildRoomItem(context, viewModel, room, key: ValueKey(room.id));
      },
    );
  }

  Widget _buildRoomItem(
    BuildContext context,
    ChatListViewModel viewModel,
    models.Room room, {
    Key? key,
  }) {
    final roomId = room.id;
    final currentUserId = context.read<AuthState>().userId ?? '';

    // Find partner id from participants list (excluding current user)
    String partnerId = '';
    for (final p in room.participants) {
      if (p.isNotEmpty && p != currentUserId) {
        partnerId = p;
        break;
      }
    }

    // Participants are pre-fetched in the ViewModel via fetchMultiple before
    // rooms are emitted, so the cache is warm by the time we render.
    final userCache = sl<UserCacheService>();
    final partnerUser = partnerId.isNotEmpty ? userCache.get(partnerId) : null;
    final partnerName = partnerUser?.name ?? partnerId;

    // ProfilePictureWidget has its own internal StreamBuilder to handle
    // real-time updates (e.g. profile picture changes).
    final leading = partnerId.isNotEmpty
        ? ProfilePictureWidget(
            user:
                partnerUser ??
                models.User(
                  id: partnerId,
                  name: partnerName,
                  email: '',
                  hasProfilePicture: false,
                ),
            size: 48,
            showBorder: false,
            variant: 'thumbnail',
          )
        : const CircleAvatar(child: Icon(Icons.chat_bubble));

    return Dismissible(
      key: key ?? ValueKey(roomId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show action sheet instead of dismissing
        return await _showChatActionsSheet(
          context,
          viewModel,
          roomId,
          partnerName,
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppBorders.borderRadiusNormal,
        ),
        child: const Icon(Icons.more_horiz, color: AppColors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppBorders.borderRadiusNormal),
        child: InkWell(
          borderRadius: AppBorders.borderRadiusNormal,
          onTap: () => _onRoomTap(
            context,
            viewModel,
            roomId,
            partnerId,
            partnerName,
            partnerUser,
          ),
          child: ListTile(
            leading: leading,
            title: Text(
              partnerName,
              style: AppTypography.headingXSmall.copyWith(
                color: AppColors.white,
              ),
            ),
            subtitle: Text(
              viewModel.getLastMessageSubtitle(room),
              style: AppTypography.captionSmall,
            ),
            trailing: _buildRoomTrailing(viewModel, room),
          ),
        ),
      ),
    );
  }

  /// Show action sheet for chat operations
  Future<bool> _showChatActionsSheet(
    BuildContext context,
    ChatListViewModel viewModel,
    String roomId,
    String partnerName,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: AppBorders.borderRadiusSheet,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: AppBorders.borderRadiusSheet,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: AppSpacing.spacing12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: AppBorders.borderRadiusTiny,
                      ),
                    ),
                    SizedBox(height: AppSpacing.spacing20),
                    Text(
                      partnerName,
                      style: AppTypography.bodyEmphasis.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.spacing16),
                    ListTile(
                      leading: const Icon(
                        Icons.cleaning_services,
                        color: AppColors.textPrimary,
                      ),
                      title: const Text('Clear Chat'),
                      subtitle: const Text(
                        'Delete all messages but keep the conversation',
                      ),
                      onTap: () => Navigator.of(ctx).pop('clear'),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Delete Chat',
                        style: AppTypography.bodyRegular.copyWith(color: AppColors.error),
                      ),
                      subtitle: const Text(
                        'Permanently delete this conversation',
                      ),
                      onTap: () => Navigator.of(ctx).pop('delete'),
                    ),
                    SizedBox(height: AppSpacing.spacing8),
                    ListTile(
                      leading: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      title: const Text('Cancel'),
                      onTap: () => Navigator.of(ctx).pop(null),
                    ),
                    SizedBox(height: AppSpacing.spacing8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!context.mounted) return false;

    if (result == 'clear') {
      final confirm = await _showConfirmDialog(
        context,
        title: 'Clear Chat',
        message:
            'This will delete all messages and media in this conversation. This action cannot be undone.',
      );
      if (confirm == true) {
        final success = await viewModel.clearChat(roomId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Chat cleared' : 'Failed to clear chat'),
            ),
          );
        }
      }
    } else if (result == 'delete') {
      final confirm = await _showConfirmDialog(
        context,
        title: 'Delete Chat',
        message:
            'This will permanently delete this conversation and all its messages and media. This action cannot be undone.',
      );
      if (confirm == true) {
        final success = await viewModel.deleteRoom(roomId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Chat deleted' : 'Failed to delete chat'),
            ),
          );
        }
      }
    }

    return false; // Never actually dismiss the item
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            label: 'Cancel',
          ),
          AppButtonVariants.dialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            label: title.contains('Delete') ? 'Delete' : 'Clear',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTrailing(ChatListViewModel viewModel, models.Room room) {
    return StreamBuilder<int>(
      stream: viewModel.unreadMessagesService.getRoomUnreadCountStream(room.id).distinct(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (room.lastMessageDateTime != null)
              Text(
                viewModel.formatMessageTime(room.lastMessageDateTime!),
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (unreadCount > 0) ...[
              SizedBox(width: AppSpacing.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppBorders.borderRadiusNormal,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: AppTypography.captionEmphasis.copyWith(
                    color: AppColors.background,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _onRoomTap(
    BuildContext context,
    ChatListViewModel viewModel,
    String roomId,
    String partnerId,
    String partnerName,
    models.User? partnerUser,
  ) {
    if (roomId.isEmpty) return;

    // Capture context before any async operations
    final nav = Navigator.of(context);

    // Mark room as read in background (don't await - fire and forget)
    viewModel.markRoomAsRead(roomId);

    // Navigate immediately without waiting for Firestore write
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(
            roomId: roomId,
            partnerId: partnerId,
            partnerName: partnerName,
            peerProfilePictureUrl: partnerUser?.profilePictureUrl,
          ),
        ),
      );
    });
  }
}
