import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/calling/domain/repositories/call_history_repository.dart';

/// Firebase implementation of [CallHistoryRepository]
///
/// Uses Firestore for storing and retrieving call history entries.
/// Call history is stored at: users/{userId}/call_history/{callHistoryId}
class FirebaseCallHistoryRepository implements CallHistoryRepository {
  final FirebaseFirestore _firestore;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'FirebaseCallHistoryRepository';

  /// Collection path for call history subcollection
  static const String _usersCollection = 'users';
  static const String _callHistorySubcollection = 'call_history';
  static const String _createdAtField = 'created_at';

  FirebaseCallHistoryRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Gets the call history collection reference for a user
  CollectionReference<Map<String, dynamic>> _getCallHistoryCollection(
    String userId,
  ) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_callHistorySubcollection);
  }

  @override
  Stream<QuerySnapshot> getCallHistoryStream(String userId) {
    return _getCallHistoryCollection(
      userId,
    ).orderBy(_createdAtField, descending: true).snapshots();
  }

  @override
  Future<bool> deleteCallHistoryEntry(
    String userId,
    String callHistoryId,
  ) async {
    try {
      await _getCallHistoryCollection(userId).doc(callHistoryId).delete();
      _log.info('Deleted call history entry: $callHistoryId', tag: _tag);
      return true;
    } catch (e) {
      _log.error('Failed to delete entry $callHistoryId', tag: _tag, error: e);
      return false;
    }
  }

  @override
  Future<int> deleteCallHistoryEntries(
    String userId,
    List<String> callHistoryIds,
  ) async {
    if (callHistoryIds.isEmpty) return 0;

    int deletedCount = 0;
    final collection = _getCallHistoryCollection(userId);

    // Use batched writes for efficiency (max 500 per batch)
    final batches = <WriteBatch>[];
    var currentBatch = _firestore.batch();
    int operationCount = 0;

    for (final id in callHistoryIds) {
      currentBatch.delete(collection.doc(id));
      operationCount++;

      if (operationCount >= 500) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        operationCount = 0;
      }
    }

    // Add remaining operations
    if (operationCount > 0) {
      batches.add(currentBatch);
    }

    // Commit all batches
    for (final batch in batches) {
      try {
        await batch.commit();
        deletedCount += callHistoryIds.length ~/ batches.length;
      } catch (e) {
        _log.error('Batch delete error', tag: _tag, error: e);
      }
    }

    _log.info('Deleted $deletedCount of ${callHistoryIds.length} entries', tag: _tag);
    return deletedCount;
  }

  @override
  Future<bool> clearAllCallHistory(String userId) async {
    try {
      final collection = _getCallHistoryCollection(userId);
      final snapshots = await collection.get();

      if (snapshots.docs.isEmpty) {
        _log.debug('No call history to clear', tag: _tag);
        return true;
      }

      // Use batched deletes for efficiency
      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      int operationCount = 0;

      for (final doc in snapshots.docs) {
        currentBatch.delete(doc.reference);
        operationCount++;

        if (operationCount >= 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }

      // Add remaining operations
      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      // Commit all batches
      for (final batch in batches) {
        await batch.commit();
      }

      _log.info('Cleared all ${snapshots.docs.length} call history entries', tag: _tag);
      return true;
    } catch (e) {
      _log.error('Failed to clear call history', tag: _tag, error: e);
      return false;
    }
  }

  @override
  Future<int> getCallHistoryCount(String userId) async {
    try {
      final snapshot = await _getCallHistoryCollection(userId).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      _log.error('Failed to get count', tag: _tag, error: e);
      return 0;
    }
  }
}
