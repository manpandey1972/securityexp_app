import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/features/calling/domain/repositories/call_history_repository.dart';
import 'package:greenhive_app/features/calling/presentation/view_models/call_history_view_model.dart';
import 'package:greenhive_app/core/di/call_dependencies.dart';
import 'package:greenhive_app/shared/widgets/profile_picture_widget.dart';
import 'package:greenhive_app/features/calling/widgets/call_history_card.dart';
import 'package:greenhive_app/features/chat/pages/chat_conversation_page.dart';
import 'package:greenhive_app/features/calling/services/call_coordinator.dart';
import 'package:greenhive_app/shared/services/dialog_service.dart';
import 'package:greenhive_app/shared/services/user_cache_service.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/widgets/error_state_widget.dart';
import 'package:greenhive_app/shared/widgets/empty_state_widget.dart';
import 'package:greenhive_app/shared/widgets/shimmer_loading.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/features/ratings/pages/rating_page.dart';
import 'package:greenhive_app/features/ratings/services/rating_service.dart';
import 'package:greenhive_app/providers/auth_provider.dart';
import 'package:greenhive_app/core/constants.dart';
import 'package:greenhive_app/data/repositories/user/user_repository.dart';

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  late final CallHistoryViewModel _viewModel;
  late final String _userId;
  bool _initialized = false;
  bool _currentUserIsExpert = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _userId = context.read<AuthState>().userId ?? '';
      if (_userId.isNotEmpty) {
        _viewModel = CallHistoryViewModel(
          repository: sl<CallHistoryRepository>(),
          userId: _userId,
        );
        _viewModel.initialize();
        _initialized = true;
        _fetchCurrentUserRole();
      }
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final profile = await sl<UserRepository>().getCurrentUserProfile();
    if (profile != null && mounted) {
      final isExpert = profile.roles.contains('Expert');
      if (isExpert != _currentUserIsExpert) {
        setState(() {
          _currentUserIsExpert = isExpert;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  // =============== Delete Confirmation Dialogs ===============

  Future<void> _confirmDeleteSelected() async {
    final count = _viewModel.state.selectedCount;
    final confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Delete Selected',
      message: 'Delete $count selected call${count > 1 ? 's' : ''}?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      DialogService.showLoadingDialog(context, message: 'Deleting...');
      await _viewModel.deleteSelected();
      if (mounted) DialogService.dismissDialog(context);
    }
  }

  Future<void> _confirmClearAll(int totalCount) async {
    final confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Clear All',
      message:
          'Delete all $totalCount call history entries? This cannot be undone.',
      confirmLabel: 'Clear All',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      DialogService.showLoadingDialog(context, message: 'Clearing history...');
      await _viewModel.clearAll();
      if (mounted) DialogService.dismissDialog(context);
    }
  }

  // =============== Build Methods ===============

  PreferredSizeWidget _buildAppBar(List<QueryDocumentSnapshot> allCalls) {
    final state = _viewModel.state;

    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _viewModel.exitSelectionMode,
        ),
        title: Text('${state.selectedCount} selected'),
        actions: [
          // Select/Deselect all toggle
          IconButton(
            icon: Icon(state.allSelected ? Icons.deselect : Icons.select_all),
            tooltip: state.allSelected ? 'Deselect all' : 'Select all',
            onPressed: () {
              if (state.allSelected) {
                _viewModel.deselectAll();
              } else {
                _viewModel.selectAll(allCalls);
              }
            },
          ),
          // Delete selected
          if (state.hasSelection)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              tooltip: 'Delete selected',
              onPressed: _confirmDeleteSelected,
            ),
        ],
      );
    }

    // Normal app bar with clear all option
    return AppBar(
      backgroundColor: AppColors.surface,
      title: const Text('Call History'),
      actions: [
        if (allCalls.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'select') {
                _viewModel.enterSelectionMode();
              } else if (value == 'clear_all') {
                _confirmClearAll(allCalls.length);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    Icon(Icons.checklist, size: 20),
                    SizedBox(width: 12),
                    Text(AppStrings.select),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text(AppStrings.clearAll, style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCallCard(QueryDocumentSnapshot doc, {Key? key}) {
    final callData = doc.data() as Map<String, dynamic>;
    final callHistoryId = doc.id;

    // Extract call data
    final durationSeconds = callData['duration_seconds'] as int? ?? 0;
    final createdAtData = callData['created_at'];
    final direction = callData['direction'] as String? ?? 'unknown';
    final callerId = callData['caller_id'] as String? ?? '';
    final calleeId = callData['callee_id'] as String? ?? '';
    final callerName = callData['caller_name'] as String? ?? 'Unknown';
    
    // Get the call_id for rating (fallback to doc.id if not present)
    final callId = callData['call_id'] as String? ?? callHistoryId;

    // Determine the other user based on direction
    final otherUserId = direction == 'outgoing' ? calleeId : callerId;

    // Handle Timestamp conversion
    DateTime createdAt;
    if (createdAtData is Timestamp) {
      createdAt = createdAtData.toDate();
    } else if (createdAtData is DateTime) {
      createdAt = createdAtData;
    } else {
      createdAt = DateTime.now();
    }

    final callStatus = callData['status'] as String? ?? 'unknown';
    final displayDirection =
        (callStatus == 'ended' || callStatus == 'answered') &&
            (durationSeconds > 0)
        ? direction
        : 'missed';

    // Participants are pre-fetched in the ViewModel via fetchMultiple before
    // the UI is notified, so the cache is warm by the time we render.
    final userCache = sl<UserCacheService>();
    var otherUserObj = userCache.get(otherUserId);
    
    // If not in cache (shouldn't happen normally), trigger fetch for next rebuild
    if (otherUserObj == null && otherUserId.isNotEmpty) {
      userCache.getOrFetch(otherUserId); // Fire and forget - will be cached for next rebuild
    }

    // Resolve display name: prefer cached user name, then stored name from call doc
    final displayName = otherUserObj?.name ??
        (direction == 'outgoing'
            ? (callData['callee_name'] as String? ?? 'Unknown')
            : callerName);

    // Always use ProfilePictureWidget — it has its own internal StreamBuilder
    // for real-time updates. Pass cached user when available, otherwise a
    // placeholder user so the widget can fetch the profile internally.
    final customLeading = ProfilePictureWidget(
      key: ValueKey('profile_$otherUserId'),  // Key by user ID for proper state management
      user: otherUserObj ??
          models.User(
            id: otherUserId,
            name: displayName,
            email: '',
            hasProfilePicture: false,
          ),
      size: 48,
      showBorder: false,
      variant: 'thumbnail',
    );

    final state = _viewModel.state;
    final isSelected = state.selectedIds.contains(callHistoryId);

    return CallHistoryCard(
      key: key ?? ValueKey(callHistoryId),
      displayName: displayName,
      direction: displayDirection,
      isVideoCall: callData['is_video'] == true,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      otherUser: otherUserObj,
      customLeading: customLeading,
      isSelectionMode: state.isSelectionMode,
      isSelected: isSelected,
      onTap: state.isSelectionMode
          ? () => _viewModel.toggleSelection(callHistoryId)
          : null,
      onLongPress: () {
        if (!state.isSelectionMode) {
          _viewModel.enterSelectionMode(initialSelection: callHistoryId);
        }
      },
      onDelete: () => _viewModel.deleteEntry(
        callHistoryId,
      ), // Swipe delete without confirmation
      onChatTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatConversationPage(
              partnerId: otherUserId,
              partnerName: displayName,
            ),
          ),
        );
      },
      onAudioCallTap: () {
        CallCoordinator.startCall(
          context: context,
          partnerId: otherUserId,
          partnerName: displayName,
          isVideo: false,
        );
      },
      onVideoCallTap: () {
        CallCoordinator.startCall(
          context: context,
          partnerId: otherUserId,
          partnerName: displayName,
          isVideo: true,
        );
      },
      // Rating support - enable if:
      // 1. Call wasn't missed
      // 2. Other user is an Expert
      // 3. Current user is NOT an expert (experts don't rate)
      onRateTap: displayDirection != 'missed' &&
              (otherUserObj?.roles.contains('Expert') ?? false) &&
              !_currentUserIsExpert
          ? () => _navigateToRatingPage(
                expertId: otherUserId,
                expertName: displayName,
                callId: callId,
              )
          : null,
    );
  }

  Future<void> _navigateToRatingPage({
    required String expertId,
    required String expertName,
    required String callId,
  }) async {
    // Check if already rated to avoid unnecessary navigation
    final ratingService = sl<RatingService>();
    final alreadyRated = await ratingService.hasRatedBooking(callId);
    
    if (alreadyRated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already rated this session'),
            backgroundColor: AppColors.info,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingPage(
          expertId: expertId,
          expertName: expertName,
          bookingId: callId,
          sessionDate: DateTime.now(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.list(
      title: 'No calls yet',
      description: 'Your call history will appear here',
    );
  }

  Widget _buildLoadingState() {
    return ShimmerLoading.list(
      itemCount: 8,
      itemBuilder: () => ShimmerLoading.callHistoryItem(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Center(child: Text(AppStrings.pleaseLogInToViewCallHistory));
    }

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final allCalls = _viewModel.callHistoryDocs;

        // Show error state
        if (state.error != null && !state.loading) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              title: const Text('Call History'),
            ),
            body: ErrorStateWidget.server(
              title: 'Failed to load call history',
              message: state.error,
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(allCalls),
          body: state.loading
              ? _buildLoadingState()
              : allCalls.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: allCalls.length,
                      itemBuilder: (context, index) => _buildCallCard(
                        allCalls[index],
                        key: ValueKey(allCalls[index].id),
                      ),
                    ),
        );
      },
    );
  }
}
