import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:greenhive_app/core/constants.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/shared/services/upload_manager.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/data/repositories/chat/chat_repositories.dart';
import 'package:greenhive_app/data/repositories/interfaces/pagination_cursor.dart';

/// Service to handle pagination and scroll logic for chat messages
class ChatScrollHandler {
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final ChatMessageRepository messageRepository;
  final String roomId;
  final Function(bool isLoading) onLoadingStateChanged;
  final Function(List<Message> messages) onMessagesLoaded;
  final Function() onNoMoreMessages;
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'ChatScrollHandler';

  // State
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  PaginationCursor? _oldestMessageCursor;

  bool _hasInitiallyLoadedMessages = false;

  ChatScrollHandler({
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.messageRepository,
    required this.roomId,
    required this.onLoadingStateChanged,
    required this.onMessagesLoaded,
    required this.onNoMoreMessages,
  });

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get hasInitiallyLoadedMessages => _hasInitiallyLoadedMessages;
  PaginationCursor? get oldestMessageCursor =>
      _oldestMessageCursor;

  /// Initialize with first message batch and set cursor for pagination
  Future<void> initialize(List<Message> messages) async {
    final stopwatch = Stopwatch()..start();
    if (!_hasInitiallyLoadedMessages && messages.isNotEmpty) {
      // Get the cursor to the oldest message for pagination
      await ErrorHandler.handle<void>(
        operation: () async {
          _log.debug(
            'Starting cursor initialization with ${messages.length} messages...',
            tag: _tag,
          );
          final (_, cursor) = await messageRepository.getLastMessagesWithCursor(
            roomId,
            limit: AppConstants.messageBatchSize,
          );
          _oldestMessageCursor = cursor;
          _hasInitiallyLoadedMessages = true;
          _log.debug(
            'Initialized cursor in ${stopwatch.elapsedMilliseconds}ms',
            tag: _tag,
          );
        },
        onError: (error) => _log.error(
          'Failed to initialize cursor in ${stopwatch.elapsedMilliseconds}ms: $error',
          tag: _tag,
        ),
      );
    }
  }

  /// Handle scroll event and trigger pagination if needed
  void handleScroll(List<Message> currentMessages) {
    if (itemPositionsListener.itemPositions.value.isEmpty) return;

    // Get uploading count from UploadManager
    final uploadingCount = sl<UploadManager>().getUploadsForRoom(roomId).length;

    // In a reversed list, "top" (oldest messages) are at high indices
    // Check if user has scrolled to top of list (where older messages are)
    final positions = itemPositionsListener.itemPositions.value;
    final maxIndex = currentMessages.length + uploadingCount - 1;
    // isNearTop: Check if any visible item is in the top 5 (high indices in reversed list)
    final isNearTop = positions.any(
      (position) => position.index >= maxIndex - 4,
    );

    if (isNearTop && !_isLoadingMore && _hasMoreMessages) {
      // Set flag immediately to prevent concurrent loads
      _isLoadingMore = true;
      loadMoreMessages(currentMessages);
    }
  }

  /// Load older messages with pagination
  Future<void> loadMoreMessages(List<Message> currentMessages) async {
    // Guard against empty messages (isLoadingMore already checked in handleScroll)
    if (!_hasMoreMessages || currentMessages.isEmpty) {
      _log.debug(
        'Load skipped - hasMore:$_hasMoreMessages, empty:${currentMessages.isEmpty}',
        tag: _tag,
      );
      _isLoadingMore = false;
      onLoadingStateChanged(false);
      return;
    }

    // Notify loading started
    onLoadingStateChanged(true);

    // If we don't have a cursor yet, try to initialize it
    if (_oldestMessageCursor == null) {
      _log.debug('No cursor set, initializing...', tag: _tag);
      await ErrorHandler.handle<void>(
        operation: () async {
          final (_, cursor) = await messageRepository.getLastMessagesWithCursor(
            roomId,
            limit: AppConstants.messageBatchSize,
          );
          _oldestMessageCursor = cursor;
          if (_oldestMessageCursor == null) {
            _log.debug(
              'Failed to get initial cursor - may be at end',
              tag: _tag,
            );
            _hasMoreMessages = false;
            _isLoadingMore = false;
            onLoadingStateChanged(false);
            return;
          }
        },
        onError: (error) {
          _log.error('Error initializing cursor: $error', tag: _tag);
          _isLoadingMore = false;
          onLoadingStateChanged(false);
          return;
        },
      );
    }

    // Guard: ensure we have a valid cursor before trying to load more
    if (_oldestMessageCursor == null) {
      _log.debug('Cursor is null - cannot load more messages', tag: _tag);
      _hasMoreMessages = false;
      _isLoadingMore = false;
      onLoadingStateChanged(false);
      return;
    }

    await ErrorHandler.handle<void>(
      operation: () async {
        _log.debug(
          'Loading older messages... Current oldest msg: ${currentMessages.first.timestamp.toDate()}',
          tag: _tag,
        );

        final (newMessages, newCursor) = await messageRepository
            .loadOlderMessages(
              roomId,
              cursor: _oldestMessageCursor!,
              limit: AppConstants.messageBatchSize,
            );

        _log.debug('Got ${newMessages.length} older messages', tag: _tag);
        if (newMessages.isNotEmpty) {
          _log.debug(
            '  - Oldest of new batch: ${newMessages.first.timestamp.toDate()}',
            tag: _tag,
          );
          _log.debug(
            '  - Newest of new batch: ${newMessages.last.timestamp.toDate()}',
            tag: _tag,
          );
        }

        if (newMessages.isNotEmpty) {
          // Check for duplicates
          final existingIds = currentMessages.map((m) => m.id).toSet();
          final uniqueNew = newMessages
              .where((m) => !existingIds.contains(m.id))
              .toList();

          _log.debug(
            'After dedup: ${uniqueNew.length}/${newMessages.length} are new',
            tag: _tag,
          );

          if (uniqueNew.isNotEmpty) {
            _oldestMessageCursor = newCursor;
            // Only stop pagination if we got fewer messages than requested AND the result was non-empty
            // This means we're at the end of the collection
            _hasMoreMessages =
                newMessages.length >= AppConstants.messageBatchSize;

            _isLoadingMore = false;
            onLoadingStateChanged(false);
            onMessagesLoaded(uniqueNew);

            _log.debug(
              'Pagination SUCCESS. Total: ${currentMessages.length + uniqueNew.length}, hasMore: $_hasMoreMessages',
              tag: _tag,
            );
          } else {
            _hasMoreMessages = false;
            _isLoadingMore = false;
            onLoadingStateChanged(false);
            _log.debug(
              'All returned messages were duplicates - reached end',
              tag: _tag,
            );
          }
        } else {
          _hasMoreMessages = false;
          _isLoadingMore = false;
          onLoadingStateChanged(false);
          _log.debug('No more messages to load', tag: _tag);
        }
      },
      onError: (error) {
        _isLoadingMore = false;
        _log.error('Error loading more messages: $error', tag: _tag);
        onLoadingStateChanged(false);
      },
    );
  }

  /// Scroll to a specific message
  void scrollToMessage(Message targetMessage, List<Message> allMessages) {
    final targetIndex = allMessages.indexWhere((m) => m.id == targetMessage.id);

    if (targetIndex == -1) {
      return;
    }

    // For reversed ListView:
    // allMessages is sorted Oldest -> Newest (index 0 is oldest)
    // ListView displays Newest -> Oldest (index 0 is bottom/newest)
    // So we need to invert the index
    final listViewIndex = allMessages.length - 1 - targetIndex;

    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: listViewIndex,
        duration: DurationConstants.short,
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  /// Update cursor for pagination
  void setOldestMessageCursor(PaginationCursor? cursor) {
    _oldestMessageCursor = cursor;
  }

  /// Reset pagination state
  void reset() {
    _isLoadingMore = false;
    _hasMoreMessages = true;
    _oldestMessageCursor = null;
    _hasInitiallyLoadedMessages = false;
  }
}
