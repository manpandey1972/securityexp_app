import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/data/repositories/interfaces/pagination_cursor.dart';

/// Abstract interface for chat message repository operations.
/// 
/// This interface defines the contract for message data operations,
/// enabling dependency injection and easier testing through mocking.
abstract class IChatMessageRepository {
  /// Stream of messages with deduplication
  Stream<List<Message>> getMessagesStream(
    String roomId, {
    int limit = 50,
  });

  /// Get the last messages with a cursor for pagination.
  ///
  /// Returns a tuple of (messages, cursor). The cursor is an opaque
  /// [PaginationCursor] that can be passed to [loadOlderMessages].
  Future<(List<Message>, PaginationCursor?)>
      getLastMessagesWithCursor(
    String roomId, {
    int limit = 50,
  });

  /// Load older messages before [cursor] for pagination.
  ///
  /// Returns a tuple of (older messages, new cursor).
  Future<(List<Message>, PaginationCursor?)>
      loadOlderMessages(
    String roomId, {
    required PaginationCursor cursor,
    int limit = 20,
  });

  /// Send a new message to a room
  Future<Message> sendMessage(String roomId, Message message);

  /// Send a call log message
  Future<void> sendCallLogMessage({
    required String roomId,
    required String senderId,
    required String callerId,
    required bool isVideo,
    required int durationSeconds,
    required String status,
  });

  /// Update an existing message's text
  Future<void> updateMessage(
    String roomId,
    String messageId,
    String newText,
  );

  /// Delete a single message
  Future<void> deleteMessage(String roomId, String messageId);

  /// Delete multiple messages
  Future<void> deleteMessages(String roomId, List<String> messageIds);
}
