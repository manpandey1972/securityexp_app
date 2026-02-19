import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/constants.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/data/repositories/interfaces/repository_interfaces.dart';

/// Repository for chat room operations.
/// Handles room CRUD and real-time room streams.
class ChatRoomRepository implements IChatRoomRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final MediaCacheService? _mediaCacheService;
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'ChatRoomRepository';
  static const String _roomsCollection = FirestoreInstance.roomsCollection;

  ChatRoomRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    MediaCacheService? mediaCacheService,
  }) : _firestore = firestore ?? FirestoreInstance().db,
       _storage = storage ?? FirebaseStorage.instance,
       _mediaCacheService = mediaCacheService;

  /// Get list of chat rooms the user is a participant of.
  /// Falls back to cache if offline.
  @override
  Future<List<Room>> getUserRooms(String userId) async {
    return await ErrorHandler.handle<List<Room>>(
      operation: () async {
        final query = _firestore
            .collection(_roomsCollection)
            .where(
              FirestoreConstants.participantsField,
                  arrayContains: userId,
                );

            final snapshot = await query.get(
              const GetOptions(source: Source.serverAndCache),
            );
            return snapshot.docs
                .map((doc) => Room.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
          },
          fallback: <Room>[],
          onError: (error) =>
              _log.error('Error fetching user rooms: $error', tag: _tag),
        );
  }

  /// Stream of chat rooms for real-time updates.
  /// Rooms are sorted by lastMessageTime descending.
  @override
  Stream<List<Room>> getUserRoomsStream(String userId) {
    return _firestore
        .collection(_roomsCollection)
        .where(FirestoreConstants.participantsField, arrayContains: userId)
        .snapshots(includeMetadataChanges: true)
        .map<List<Room>>((snapshot) {
          try {
            final rooms = snapshot.docs
                .map((doc) => Room.fromJson({...doc.data(), 'id': doc.id}))
                .toList();

            // Sort by lastMessageTime descending (newest first)
            rooms.sort((a, b) {
              final aTime = a.lastMessageDateTime?.millisecondsSinceEpoch ?? 0;
              final bTime = b.lastMessageDateTime?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });

            return rooms;
          } catch (e, stackTrace) {
            _log.error(
              'Error parsing rooms: $e',
              tag: _tag,
              stackTrace: stackTrace,
            );
            return [];
          }
        });
  }

  /// Get or create a room between two users.
  /// Room ID format: "userA_userB" (alphabetically sorted for consistency).
  /// Throws [ChatRoomException] if both users are the same.
  @override
  Future<String> getOrCreateRoom(String userA, String userB) async {
    if (userA == userB) {
      throw ChatRoomException('Cannot create a room with the same user');
    }

    final roomId = generateRoomId(userA, userB);

    return await ErrorHandler.handle<String>(
      operation: () async {
        final docRef = _firestore.collection(_roomsCollection).doc(roomId);
        final doc = await docRef.get(
          const GetOptions(source: Source.serverAndCache),
        );

        if (!doc.exists) {
          await docRef.set({
            FirestoreConstants.participantsField: [userA, userB],
            FirestoreConstants.lastMessageField: '',
            FirestoreConstants.lastMessageTimeField:
                FieldValue.serverTimestamp(),
            FirestoreConstants.createdAtField: FieldValue.serverTimestamp(),
          });
        }

        return roomId;
      },
      fallback: roomId,
    );
  }

  /// Generate a consistent room ID for two users.
  static String generateRoomId(String userA, String userB) {
    final sortedUsers = [userA, userB]..sort();
    return '${sortedUsers[0]}_${sortedUsers[1]}';
  }

  /// Update room's last message metadata.
  @override
  Future<void> updateLastMessage({
    required String roomId,
    required String lastMessage,
  }) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _firestore.collection(_roomsCollection).doc(roomId).update({
          FirestoreConstants.lastMessageField: lastMessage,
          FirestoreConstants.lastMessageTimeField: FieldValue.serverTimestamp(),
        });
      },
    );
  }

  /// Clear all messages in a chat room but keep the room itself.
  /// Also deletes all media files from Firebase Storage.
  /// Resets unread count to 0 for both participants.
  /// Returns true if successful, false otherwise.
  @override
  Future<bool> clearChat(String roomId) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        // Get the room to find participants
        final roomDoc = await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .get();
        if (!roomDoc.exists) {
              _log.warning('Room not found', tag: _tag);
              return false;
            }

            final participants = List<String>.from(
              roomDoc.data()?['participants'] ?? [],
            );

            // Get all messages
            final messagesSnapshot = await _firestore
                .collection(_roomsCollection)
                .doc(roomId)
                .collection(FirestoreInstance.messagesCollection)
                .get();

            if (messagesSnapshot.docs.isEmpty) {
              // Still try to clean up any orphaned storage files
              await _deleteRoomMediaFromStorage(roomId);
              // Reset unread counts for both participants
              await _resetUnreadCounts(participants, roomId);
              return true;
            }

            // Delete all media from Firebase Storage first
            await _deleteRoomMediaFromStorage(roomId);

            // Chunk into batches of 500 (Firestore limit)
            final chunks = _chunkList(messagesSnapshot.docs, 500);
            for (final chunk in chunks) {
              final batch = _firestore.batch();
              for (final doc in chunk) {
                batch.delete(doc.reference);
              }
              await batch.commit();
            }

            // Reset the room's last message
            await _firestore.collection(_roomsCollection).doc(roomId).update({
              FirestoreConstants.lastMessageField: '',
              FirestoreConstants.lastMessageTimeField:
                  FieldValue.serverTimestamp(),
            });

            // Reset unread counts for both participants
            await _resetUnreadCounts(participants, roomId);

            return true;
          },
          fallback: false,
          onError: (error) =>
              _log.error('Error clearing chat: $error', tag: _tag),
        );
  }

  /// Delete a room and all its messages.
  /// Also deletes all media files from Firebase Storage and local cache.
  /// Deletes the room tracking documents from both participants' user collections.
  @override
  Future<void> deleteRoom(String roomId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        // Get the room to find participants before deleting
        final roomDoc = await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .get();
        final participants = roomDoc.exists
            ? List<String>.from(roomDoc.data()?['participants'] ?? [])
            : <String>[];

        // Delete all media from Firebase Storage first
        await _deleteRoomMediaFromStorage(roomId);

        // Clear local media cache for this room
        if (_mediaCacheService != null) {
          try {
            await _mediaCacheService.clearCache(roomId);
            _log.info('Cleared local media cache for room', tag: _tag);
          } catch (e, stackTrace) {
            _log.error(
              'Failed to clear local cache: $e',
              tag: _tag,
              stackTrace: stackTrace,
            );
          }
        }

        // Delete all messages in batch (Firestore limit: 500 per batch)
        final messagesSnapshot = await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .collection(FirestoreInstance.messagesCollection)
            .get();

        // Chunk into batches of 500
        final chunks = _chunkList(messagesSnapshot.docs, 500);
        for (final chunk in chunks) {
          final batch = _firestore.batch();
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }

        // Delete the room tracking documents from both participants' user collections
        for (final userId in participants) {
          try {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('rooms')
                .doc(roomId)
                .delete();
          } catch (e, stackTrace) {
            _log.error(
              'Failed to delete room tracking',
              tag: _tag,
              stackTrace: stackTrace,
            );
          }
        }

        // Delete the room document itself
        await _firestore.collection(_roomsCollection).doc(roomId).delete();
      },
      onError: (error) => _log.error('Error deleting room: $error', tag: _tag),
    );
  }

  /// Get a room by ID.
  @override
  Future<Room?> getRoom(String roomId) async {
    return await ErrorHandler.handle<Room?>(
      operation: () async {
        final doc = await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .get(const GetOptions(source: Source.serverAndCache));

        if (!doc.exists) return null;
        return Room.fromJson({...doc.data()!, 'id': doc.id});
      },
    );
  }

  /// Helper to chunk a list into smaller lists.
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// Reset unread counts to 0 for all participants in a room.
  /// Also decrements totalUnreadCount by the amount that was previously unread.
  Future<void> _resetUnreadCounts(
    List<String> participants,
    String roomId,
  ) async {
    for (final userId in participants) {
      try {
        // First get current unread count to know how much to decrement
        final roomDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('rooms')
            .doc(roomId)
            .get();

        final currentUnread = roomDoc.data()?['unreadCount'] as int? ?? 0;

        // Reset room unread count to 0
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('rooms')
            .doc(roomId)
            .set({'unreadCount': 0}, SetOptions(merge: true));

        // Decrement totalUnreadCount if there were unread messages
        if (currentUnread > 0) {
          await _firestore.collection('users').doc(userId).update({
            'totalUnreadCount': FieldValue.increment(-currentUnread),
          });
        }
      } catch (e, stackTrace) {
        _log.error(
          'Failed to reset unread count',
          tag: _tag,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Delete all media files from Firebase Storage for a room.
  /// Media is stored at: chat_attachments/{roomId}/*
  Future<void> _deleteRoomMediaFromStorage(String roomId) async {
    try {
      final storageRef = _storage.ref('chat_attachments/$roomId');
      final listResult = await storageRef.listAll();

      // Delete all files in the room folder
      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (e, stackTrace) {
          // Log but don't fail - file might already be deleted
          _log.error(
            'Failed to delete storage file',
            tag: _tag,
            stackTrace: stackTrace,
          );
        }
      }

      // Recursively delete any subfolders
      for (final prefix in listResult.prefixes) {
        final subListResult = await prefix.listAll();
        for (final item in subListResult.items) {
          try {
            await item.delete();
          } catch (e, stackTrace) {
            _log.error(
              'Failed to delete storage file',
              tag: _tag,
              stackTrace: stackTrace,
            );
          }
        }
      }

      _log.info(
        'Deleted ${listResult.items.length} media files for room',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      // Storage folder might not exist if no media was ever sent
      _log.error(
        'No storage folder or error for room $roomId: $e',
        tag: _tag,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Exception thrown for chat room operations.
class ChatRoomException implements Exception {
  final String message;
  const ChatRoomException(this.message);

  @override
  String toString() => 'ChatRoomException: $message';
}
