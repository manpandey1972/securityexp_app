import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/features/chat/services/unread_messages_service.dart';
import 'package:securityexperts_app/features/chat_list/presentation/state/chat_list_state.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// ViewModel for ChatPage (chat list)
///
/// Manages business logic and state updates using ChangeNotifier pattern.
/// Handles room loading, real-time updates, and navigation coordination.
class ChatListViewModel extends ChangeNotifier {
  // Repository
  final ChatRoomRepository _roomRepository;
  
  // Services
  final UnreadMessagesService _unreadMessagesService;
  final MediaCacheService _mediaCacheService = sl<MediaCacheService>();
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'ChatListViewModel';

  // State
  ChatListState _state = const ChatListState();
  ChatListState get state => _state;

  // Stream subscription
  StreamSubscription<List<models.Room>>? _roomsSubscription;

  // Callbacks for parent coordination
  VoidCallback? _loadCallback;

  // Track disposed state
  bool _isDisposed = false;

  // Track if orphan cleanup has been done this session
  bool _hasCleanedOrphanedCaches = false;

  // Instance tracking for debugging
  static int _instanceCounter = 0;
  final int _instanceId;

  ChatListViewModel({
    required ChatRoomRepository roomRepository,
    required UnreadMessagesService unreadMessagesService,
  }) : _roomRepository = roomRepository,
       _unreadMessagesService = unreadMessagesService,
       _instanceId = ++_instanceCounter;

  // Getters for service access (for UI)
  UnreadMessagesService get unreadMessagesService => _unreadMessagesService;

  /// Initialize the chat list
  /// Uses stream subscription only - the stream provides initial data,
  /// so we don't need a separate loadRooms() call.
  void initialize({
    VoidCallback? onLoadRequested,
    void Function(VoidCallback)? onRegisterLoadCallback,
  }) {
    // Set loading state for initial data fetch
    _state = _state.copyWith(loading: true, clearError: true);
    notifyListeners();

    // Recalculate total unread count to fix any sync issues
    _unreadMessagesService.recalculateTotalUnreadCount();

    // Start listening to room updates immediately
    // The stream will emit initial data, so no separate fetch needed
    final user = sl<FirebaseAuth>().currentUser;
    if (user != null) {
      _subscribeToRoomUpdates(user.uid);
    }

    // Register the load callback with parent
    if (onRegisterLoadCallback != null && _loadCallback != null) {
      onRegisterLoadCallback(_loadCallback!);
    }

    // NOTE: Removed onLoadRequested?.call() - the stream subscription
    // already provides initial data, so calling loadRooms() was redundant
    // and caused duplicate Firestore reads
  }

  /// Set the load callback (called by parent to trigger refresh)
  void setLoadCallback(VoidCallback callback) {
    _loadCallback = callback;
  }

  /// Load rooms from Firestore
  /// Note: This is now primarily used for manual refresh/pull-to-refresh.
  /// Initial load comes from the stream subscription.
  Future<void> loadRooms() async {
    if (_isDisposed) return;

    // Don't show loading spinner if we already have rooms (refresh scenario)
    final isInitialLoad = _state.rooms.isEmpty;
    if (isInitialLoad) {
      _state = _state.copyWith(loading: true, clearError: true);
      if (!_isDisposed) notifyListeners();
    }

    try {
      final user = sl<FirebaseAuth>().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch rooms from Firestore (pre-sorted by repository)
      final rooms = await _roomRepository.getUserRooms(user.uid);

      if (_isDisposed) return;

      // Prefetch participant profiles before notifying the UI
      await _prefetchParticipants(rooms);

      if (_isDisposed) return;

      _state = _state.copyWith(loading: false, rooms: rooms, clearError: true);
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      _log.error('Error loading rooms', tag: _tag, error: e);
      if (_isDisposed) return;

      _state = _state.copyWith(loading: false, error: e.toString());
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Subscribe to real-time room updates (when last message changes)
  void _subscribeToRoomUpdates(String userId) {
    _roomsSubscription?.cancel();

    _roomsSubscription = _roomRepository
        .getUserRoomsStream(userId)
        .listen(
          (updatedRooms) async {
            if (_isDisposed) return;

            // Rooms are already sorted by the repository stream

            // Prefetch participant profiles BEFORE notifying the UI.
            // This ensures the cache is warm so names/avatars render instantly
            // instead of briefly showing UserIDs while Firestore fetches complete.
            await _prefetchParticipants(updatedRooms);

            if (_isDisposed) return;

            // Clear loading state after first emission
            _state = _state.copyWith(rooms: updatedRooms, loading: false, clearError: true);
            if (!_isDisposed) notifyListeners();

            // Clean up orphaned caches once per session (after initial room load)
            if (!_hasCleanedOrphanedCaches && updatedRooms.isNotEmpty) {
              _cleanOrphanedCaches(updatedRooms);
            }
          },
          onError: (e) {
            _log.error('Error in rooms stream (instance $_instanceId)', tag: _tag, error: e);
            // Set error state and clear loading
            if (!_isDisposed) {
              _state = _state.copyWith(loading: false, error: e.toString());
              notifyListeners();
            }
          },
        );
  }

  /// Prefetch participant user profiles using a batch Firestore query.
  /// Awaited before notifying the UI so the cache is warm on first render.
  /// Uses fetchMultiple which batches into 'whereIn' queries of 10 and
  /// skips users already cached — so subsequent calls are instant.
  Future<void> _prefetchParticipants(List<models.Room> rooms) async {
    final currentUserId = sl<FirebaseAuth>().currentUser?.uid;
    if (currentUserId == null) return;

    final userCache = sl<UserCacheService>();
    final participantIds = <String>[];

    // Collect all unique participant IDs (excluding current user)
    for (final room in rooms) {
      for (final participantId in room.participants) {
        if (participantId.isNotEmpty &&
            participantId != currentUserId &&
            !participantIds.contains(participantId)) {
          participantIds.add(participantId);
        }
      }
    }

    if (participantIds.isEmpty) return;

    try {
      await userCache.fetchMultiple(participantIds);
    } catch (e) {
      _log.warning('Failed to prefetch participants: $e', tag: _tag);
    }
  }

  /// Clean up cached media for rooms that no longer exist
  Future<void> _cleanOrphanedCaches(List<models.Room> activeRooms) async {
    if (_hasCleanedOrphanedCaches) return;
    _hasCleanedOrphanedCaches = true;

    final activeRoomIds = activeRooms.map((r) => r.id).toList();
    final deletedCount = await _mediaCacheService.clearOrphanedCaches(activeRoomIds);
    if (deletedCount > 0) {
      _log.debug('Cleaned $deletedCount orphaned cache(s)', tag: _tag);
    }
  }

  /// Mark a room as read (called before navigation)
  Future<void> markRoomAsRead(String roomId) async {
    try {
      await _unreadMessagesService.markRoomAsRead(roomId);
    } catch (e) {
      // Silently fail
    }
  }

  /// Get last message subtitle with icon
  String getLastMessageSubtitle(models.Room room) {
    if (room.lastMessage.isEmpty) {
      return 'No messages yet';
    }

    switch (room.lastMessage.toLowerCase()) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '📹 Video';
      case 'audio':
        return '🎵 Audio';
      case 'doc':
        return '📄 Document';
      default:
        return room.lastMessage;
    }
  }

  /// Format message time (today shows time, older shows date+time)
  String formatMessageTime(DateTime dateTime) {
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final hour12 = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour12:$minute $ampm';

    // Check if the message is from today
    final now = DateTime.now();
    final isToday =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      return time;
    } else {
      // Show date and time for older messages
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthName = months[dateTime.month - 1];
      return '$monthName ${dateTime.day}, $time';
    }
  }

  /// Clear all messages in a room but keep the room.
  /// Also deletes media from Firebase Storage.
  Future<bool> clearChat(String roomId) async {
    if (_isDisposed) return false;

    final result = await _roomRepository.clearChat(roomId);
    return result;
  }

  /// Delete a room and all its messages.
  /// Also deletes media from Firebase Storage.
  Future<bool> deleteRoom(String roomId) async {
    if (_isDisposed) return false;

    try {
      await _roomRepository.deleteRoom(roomId);
      // Remove from local state immediately for responsive UI
      _state = _state.copyWith(
        rooms: _state.rooms.where((r) => r.id != roomId).toList(),
      );
      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      _log.error('Failed to delete room', tag: _tag, error: e);
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _roomsSubscription?.cancel();
    super.dispose();
  }
}
