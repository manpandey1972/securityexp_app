import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/data/models/call_log.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';

class CallLogService {
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'CallLogService';
  
  static final CallLogService _instance = CallLogService._internal();

  // Use singleton Firestore instance
  final FirebaseFirestore _firestore = FirestoreInstance().db;

  CallLogService._internal();

  factory CallLogService() {
    return _instance;
  }

  // Save a new call log
  Future<void> saveCallLog(CallLog callLog) async {
    try {
      // Use Firestore's auto-generated document ID instead of callLog.id
      await _firestore.collection('callLogs').add(callLog.toMap());
    } catch (e) {
      _log.error('Error saving call log', tag: _tag, error: e);
      // Don't rethrow - silently fail to avoid disrupting user experience
    }
  }

  // Get call history for current user
  Future<List<CallLog>> getUserCallHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('callLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('callTime', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => CallLog.fromMap(doc.data())).toList();
    } catch (e) {
      _log.error('Error fetching call history', tag: _tag, error: e);
      return [];
    }
  }

  // Stream of recent calls
  Stream<List<CallLog>> getUserCallHistoryStream(String userId) {
    return _firestore
        .collection('callLogs')
        .where('userId', isEqualTo: userId)
        .orderBy('callTime', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CallLog.fromMap(doc.data())).toList(),
        )
        .handleError((e) {
          _log.error('Error in getUserCallHistoryStream', tag: _tag, error: e);
          return <CallLog>[];
        });
  }

  // Delete a call log
  Future<void> deleteCallLog(String callLogId) async {
    try {
      await _firestore.collection('callLogs').doc(callLogId).delete();
    } catch (e) {
      _log.error('Error deleting call log', tag: _tag, error: e);
      // Don't rethrow - silently fail
    }
  }

  // Clear all call logs for a user (admin only)
  Future<void> clearUserCallHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('callLogs')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      _log.error('Error clearing call history', tag: _tag, error: e);
      // Don't rethrow - silently fail
    }
  }
}
