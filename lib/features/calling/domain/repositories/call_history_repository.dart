import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository interface for call history operations
///
/// Provides CRUD operations for user's call history,
/// following the Repository Pattern for separation of concerns.
abstract class CallHistoryRepository {
  /// Stream call history for real-time updates
  ///
  /// Returns a stream of QuerySnapshots for the user's call history,
  /// ordered by creation time (most recent first).
  Stream<QuerySnapshot> getCallHistoryStream(String userId);

  /// Delete a single call history entry
  ///
  /// Returns true if deletion was successful, false otherwise.
  Future<bool> deleteCallHistoryEntry(String userId, String callHistoryId);

  /// Delete multiple call history entries
  ///
  /// Returns the number of entries successfully deleted.
  Future<int> deleteCallHistoryEntries(
    String userId,
    List<String> callHistoryIds,
  );

  /// Delete all call history for a user
  ///
  /// Returns true if all entries were deleted successfully.
  Future<bool> clearAllCallHistory(String userId);

  /// Get total count of call history entries
  ///
  /// Useful for displaying "X items selected" or confirmation messages.
  Future<int> getCallHistoryCount(String userId);
}
