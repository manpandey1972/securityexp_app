import 'package:securityexperts_app/data/models/models.dart';

/// Abstract interface for chat room repository operations.
/// 
/// This interface defines the contract for chat room data operations,
/// enabling dependency injection and easier testing through mocking.
abstract class IChatRoomRepository {
  /// Get list of chat rooms the user is a participant of
  Future<List<Room>> getUserRooms(String userId);

  /// Stream of chat rooms for real-time updates
  Stream<List<Room>> getUserRoomsStream(String userId);

  /// Get or create a chat room between two users
  Future<String> getOrCreateRoom(String userA, String userB);

  /// Update the last message metadata for a room
  Future<void> updateLastMessage({
    required String roomId,
    required String lastMessage,
  });

  /// Clear all messages in a chat room
  Future<bool> clearChat(String roomId);

  /// Delete a chat room and all its messages
  Future<void> deleteRoom(String roomId);

  /// Get a specific room by ID
  Future<Room?> getRoom(String roomId);
}
