import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Service to manage unread message counts
class UnreadMessagesService {
  UnreadMessagesService({
    FirebaseAuth? firebaseAuth,
    FirestoreInstance? firestoreInstance,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestoreInstance = firestoreInstance ?? FirestoreInstance();

  final FirebaseAuth _auth;
  final FirestoreInstance _firestoreInstance;
  final _log = sl<AppLogger>();
  static const _tag = 'UnreadMessagesService';

  /// Convert Firestore value to int, handling both int and double types
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  /// Get total unread count for current user
  Future<int> getTotalUnreadCount() async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        final user = _auth.currentUser;
        if (user == null) return 0;

        final doc = await _firestoreInstance.db
            .collection('users')
            .doc(user.uid)
            .get();
        final totalUnreadCount = _toInt(doc.data()?['totalUnreadCount']);

        return totalUnreadCount;
      },
      fallback: 0,
    );
  }

  /// Get unread count for a specific room
  Future<int> getRoomUnreadCount(String roomId) async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        final user = _auth.currentUser;
        if (user == null) return 0;

        final doc = await _firestoreInstance.db
            .collection('users')
            .doc(user.uid)
            .collection('rooms')
            .doc(roomId)
            .get();

        final unreadCount = _toInt(doc.data()?['unreadCount']);
        return unreadCount;
      },
      fallback: 0,
    );
  }

  /// Recalculate total unread count by summing up all room unread counts
  /// This fixes synchronization issues where totalUnreadCount gets out of sync
  Future<void> recalculateTotalUnreadCount() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final user = _auth.currentUser;
        if (user == null) return;

        // 1. Get all rooms for the user
        final roomsSnapshot = await _firestoreInstance.db
            .collection('users')
            .doc(user.uid)
            .collection('rooms')
            .get();

        // 2. Sum up unread counts
        int calculatedTotal = 0;
        for (var doc in roomsSnapshot.docs) {
          final unreadCount = _toInt(doc.data()['unreadCount']);
          if (unreadCount > 0) {
            calculatedTotal += unreadCount;
          }
        }

        // 3. Get current stored total
        final userDoc = await _firestoreInstance.db
            .collection('users')
            .doc(user.uid)
            .get();
        final currentStoredTotal = _toInt(userDoc.data()?['totalUnreadCount']);

        // 4. Update if different
        if (calculatedTotal != currentStoredTotal) {
          _log.warning(
            'Mismatch detected! Stored: $currentStoredTotal, Calculated: $calculatedTotal. Updating...',
            tag: _tag,
          );
          await _firestoreInstance.db.collection('users').doc(user.uid).update({
            'totalUnreadCount': calculatedTotal,
          });
          _log.debug(
            'Total unread count corrected to $calculatedTotal',
            tag: _tag,
          );
        } else {
          // Count is correct
        }
      },
      onError: (error) {
        // Log handled by ErrorHandler
      },
    );
  }

  /// Stream of total unread count for real-time updates
  Stream<int> getTotalUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    int? lastUnreadCount;

    return _firestoreInstance.db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return 0;
          }

          final data = snapshot.data();

          final totalUnreadCount = _toInt(data?['totalUnreadCount']);

          return totalUnreadCount;
        })
        .transform(
          // Deduplication: only emit when unread count actually changes
          StreamTransformer<int, int>.fromHandlers(
            handleData: (unreadCount, sink) {
              if (unreadCount != lastUnreadCount) {
                lastUnreadCount = unreadCount;
                sink.add(unreadCount);
              }
            },
          ),
        )
        .handleError((e) {
          return 0;
        });
  }

  /// Stream of unread count for a specific room
  Stream<int> getRoomUnreadCountStream(String roomId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestoreInstance.db
        .collection('users')
        .doc(user.uid)
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
          final unreadCount = _toInt(snapshot.data()?['unreadCount']);

          return unreadCount;
        })
        .handleError((e) {
          return 0;
        });
  }

  /// Mark a room as read using client-side Firestore batch write.
  /// Resets unreadCount for the room and decrements totalUnreadCount on user doc.
  /// Previously used markRoomRead cloud function — moved client-side to
  /// eliminate cold starts (see CLOUD_FUNCTION_OPTIMIZATION.md, Optimization 1).
  Future<void> markRoomAsRead(String roomId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final user = _auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        _log.debug('Marking room $roomId as read (client-side)', tag: _tag);

        final db = _firestoreInstance.db;
        final roomRef = db
            .collection('users')
            .doc(user.uid)
            .collection('rooms')
            .doc(roomId);
        final userRef = db.collection('users').doc(user.uid);

        // Read current unread count to know how much to decrement
        final roomSnap = await roomRef.get();
        final currentUnreadCount = _toInt(roomSnap.data()?['unreadCount']);

        if (currentUnreadCount == 0) {
          _log.debug('Room $roomId already read (unreadCount=0)', tag: _tag);
          return;
        }

        // Batch write: reset room unread + decrement user total
        final batch = db.batch();
        batch.set(
          roomRef,
          {
            'unreadCount': 0,
            'lastReadAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        batch.update(userRef, {
          'totalUnreadCount': FieldValue.increment(-currentUnreadCount),
          'lastReadMessageAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();

        _log.debug(
          'Room $roomId marked as read (decremented by $currentUnreadCount)',
          tag: _tag,
        );
      },
      onError: (error) {},
    );
  }

  /// Mark multiple rooms as read using a single Firestore batch write.
  /// Previously fired N parallel cloud function calls — now a single batch.
  Future<void> markRoomsAsRead(List<String> roomIds) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final user = _auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        if (roomIds.isEmpty) return;

        final db = _firestoreInstance.db;
        final userRef = db.collection('users').doc(user.uid);

        // Read all room docs in parallel to get unread counts
        final roomRefs = roomIds
            .map(
              (roomId) => db
                  .collection('users')
                  .doc(user.uid)
                  .collection('rooms')
                  .doc(roomId),
            )
            .toList();
        final roomSnaps = await Future.wait(
          roomRefs.map((ref) => ref.get()),
        );

        // Calculate total to decrement and build batch
        int totalDecrement = 0;
        final batch = db.batch();

        for (int i = 0; i < roomIds.length; i++) {
          final unread = _toInt(roomSnaps[i].data()?['unreadCount']);
          if (unread > 0) {
            totalDecrement += unread;
            batch.set(
              roomRefs[i],
              {
                'unreadCount': 0,
                'lastReadAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        }

        if (totalDecrement > 0) {
          batch.update(userRef, {
            'totalUnreadCount': FieldValue.increment(-totalDecrement),
            'lastReadMessageAt': FieldValue.serverTimestamp(),
          });
          await batch.commit();
          _log.debug(
            'Marked ${roomIds.length} rooms as read (decremented by $totalDecrement)',
            tag: _tag,
          );
        }
      },
      onError: (error) {},
    );
  }

  /// Get all rooms with unread messages
  Future<List<Map<String, dynamic>>> getRoomsWithUnreadMessages() async {
    return await ErrorHandler.handle<List<Map<String, dynamic>>>(
      operation: () async {
        final user = _auth.currentUser;
        if (user == null) return [];

        final snapshot = await _firestoreInstance.db
            .collection('users')
            .doc(user.uid)
            .collection('rooms')
            .where('unreadCount', isGreaterThan: 0)
            .get();

        final rooms = snapshot.docs
            .map(
              (doc) => {
                'roomId': doc.id,
                'unreadCount': doc.data()['unreadCount'] as int? ?? 0,
                ...doc.data(),
              },
            )
            .toList();

        return rooms;
      },
      fallback: [],
    );
  }
}
