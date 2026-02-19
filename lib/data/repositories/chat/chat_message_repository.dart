import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/core/constants.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/data/repositories/chat/chat_room_repository.dart';
import 'package:greenhive_app/data/repositories/interfaces/repository_interfaces.dart';
import 'package:greenhive_app/core/analytics/analytics_service.dart';

/// Repository for chat message operations.
/// Handles message CRUD, pagination, and real-time streams.
class ChatMessageRepository implements IChatMessageRepository {
  final FirebaseFirestore _firestore;
  final ChatRoomRepository _roomRepository;
  final AppLogger _log = sl<AppLogger>();
  final AnalyticsService _analytics = sl<AnalyticsService>();

  static const String _tag = 'ChatMessageRepo';
  static const String _roomsCollection = FirestoreInstance.roomsCollection;
  static const String _messagesCollection =
      FirestoreInstance.messagesCollection;

  ChatMessageRepository({
    FirebaseFirestore? firestore,
    required ChatRoomRepository roomRepository,
  }) : _firestore = firestore ?? FirestoreInstance().db,
       _roomRepository = roomRepository;

  // =========================================================================
  // REAL-TIME STREAMS
  // =========================================================================

  /// Stream of messages with deduplication to prevent excessive rebuilds.
  /// Uses [limit] to control initial message count.
  @override
  Stream<List<Message>> getMessagesStream(
    String roomId, {
    int limit = AppConstants.messageBatchSize,
  }) {
    int? lastMessageCount;
    String? lastMessageId;
    int? lastSnapshotHash;

    return _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .collection(_messagesCollection)
        .orderBy(FirestoreConstants.timestampField, descending: false)
        .limitToLast(limit)
        .snapshots(includeMetadataChanges: true)
        .map<List<Message>>((snapshot) {
          try {
            final messages = snapshot.docs
                .where((doc) {
                  final data = doc.data();
                  return data.containsKey(FirestoreConstants.senderIdField) &&
                      data[FirestoreConstants.senderIdField]
                          .toString()
                          .isNotEmpty;
                })
                .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
            return messages;
          } catch (e, stackTrace) {
            _log.error('Error parsing messages: $e', tag: _tag, stackTrace: stackTrace);
            return [];
          }
        })
        .transform(
          StreamTransformer<List<Message>, List<Message>>.fromHandlers(
            handleData: (messages, sink) {
              final currentMessageCount = messages.length;
              final currentMessageId = messages.isNotEmpty
                  ? messages.last.id
                  : null;
              // Include content hash to detect edits
              final currentHash = messages.isNotEmpty
                  ? Object.hashAll(messages.map((m) => '${m.id}:${m.text}'))
                  : 0;

              final hasChanged =
                  currentMessageCount != lastMessageCount ||
                  currentMessageId != lastMessageId ||
                  currentHash != lastSnapshotHash;

              if (hasChanged) {
                lastMessageCount = currentMessageCount;
                lastMessageId = currentMessageId;
                lastSnapshotHash = currentHash;
                sink.add(messages);
              }
            },
          ),
        );
  }

  // =========================================================================
  // PAGINATION
  // =========================================================================

  /// Get the last [limit] messages with a cursor for pagination.
  /// Returns (messages, cursor to oldest message).
  @override
  Future<(List<Message>, PaginationCursor?)>
  getLastMessagesWithCursor(
    String roomId, {
    int limit = AppConstants.messageBatchSize,
  }) async {
    // Try cache first
    final cachedResult = await _fetchMessages(
      roomId,
      limit: limit,
      source: Source.cache,
      showSnackbar: false,
    );

    if (cachedResult != null && cachedResult.$1.isNotEmpty) {
      return cachedResult;
    }

    // Fall back to server
    final serverResult = await _fetchMessages(
      roomId,
      limit: limit,
      source: Source.server,
    );

    return serverResult ?? (const <Message>[], null);
  }

  /// Load older messages before [cursor].
  /// Returns (older messages, new cursor to oldest of this batch).
  @override
  Future<(List<Message>, PaginationCursor?)>
  loadOlderMessages(
    String roomId, {
    required PaginationCursor cursor,
    int limit = AppConstants.messageBatchSize,
  }) async {
    final docSnapshot = cursor.as<DocumentSnapshot<Map<String, dynamic>>>();
    if (docSnapshot.id.isEmpty) {
      _log.warning('Cursor ID is empty', tag: _tag);
      return (const <Message>[], null);
    }

    final result = await ErrorHandler.handle<(List<Message>, PaginationCursor?)>(
          operation: () async {
            final snapshot = await _firestore
                .collection(_roomsCollection)
                .doc(roomId)
                .collection(_messagesCollection)
                .orderBy(FirestoreConstants.timestampField, descending: false)
                .endBeforeDocument(docSnapshot)
                .limitToLast(limit)
                .get(const GetOptions(source: Source.serverAndCache));

            final messages = snapshot.docs
                .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
                .toList();

            final newCursor = snapshot.docs.isNotEmpty
                ? PaginationCursor(snapshot.docs.first)
                : null;
            return (messages, newCursor);
          },
          fallback: (const <Message>[], null),
          onError: (error) =>
              _log.error('Error loading older messages: $error', tag: _tag),
        );

    return result;
  }

  /// Helper to fetch messages with a specific source.
  Future<(List<Message>, PaginationCursor?)?>
  _fetchMessages(
    String roomId, {
    required int limit,
    required Source source,
    bool showSnackbar = true,
  }) async {
    return await ErrorHandler.handle<(List<Message>, PaginationCursor?)>(
      operation: () async {
        // Start Firestore query trace
        final trace = _analytics.newTrace('firestore_query_messages');
        await trace.start();
        trace.putAttribute('limit', limit.toString());
        trace.putAttribute('source', source.toString());
        
        final snapshot = await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .collection(_messagesCollection)
            .orderBy(FirestoreConstants.timestampField, descending: false)
            .limitToLast(limit)
            .get(GetOptions(source: source));
        
        trace.putAttribute('doc_count', snapshot.docs.length.toString());
        await trace.stop();

        final messages = snapshot.docs
            .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
            .toList();

        final cursor = snapshot.docs.isNotEmpty
            ? PaginationCursor(snapshot.docs.first)
            : null;
        return (messages, cursor);
      },
      fallback: null,
    );
  }

  // =========================================================================
  // CRUD OPERATIONS
  // =========================================================================

  /// Send a message to a room.
  /// Returns the created message with server-generated ID.
  @override
  Future<Message> sendMessage(String roomId, Message message) async {
    final trace = _analytics.newTrace('message_send');
    trace.putAttribute('message_type', message.type.name);
    trace.putAttribute('has_media', message.mediaUrl != null ? 'true' : 'false');
    await trace.start();

    try {
      final result = await ErrorHandler.handle<Message>(
            operation: () async {
              final docRef = _firestore
                  .collection(_roomsCollection)
                  .doc(roomId)
                  .collection(_messagesCollection)
                  .doc();

              // Start Firestore write trace
              final firestoreTrace = _analytics.newTrace('firestore_write_message');
              await firestoreTrace.start();
              
              final messageData = _buildMessageData(message);
              await docRef.set(messageData);
              
              await firestoreTrace.stop();

              // Update room's last message
              final lastMessageText = _getLastMessagePreview(message);
              await _roomRepository.updateLastMessage(
                roomId: roomId,
                lastMessage: lastMessageText,
              );

              return message.copyWith(id: docRef.id);
            },
            fallback: message,
            onError: (error) =>
                _log.error('Error sending message: $error', tag: _tag),
          );
      return result;
    } catch (e) {
      trace.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  /// Send a call log message.
  @override
  Future<void> sendCallLogMessage({
    required String roomId,
    required String senderId,
    required String callerId,
    required bool isVideo,
    required int durationSeconds,
    required String status,
  }) async {
    final message = Message(
      id: '',
      senderId: senderId,
      type: MessageType.callLog,
      text: CallStatusText.fromStatus(status),
      timestamp: Timestamp.now(),
      metadata: {
        'initiatorId': callerId,
        'isVideo': isVideo,
        'duration': durationSeconds,
        'status': status,
      },
    );

    await sendMessage(roomId, message);
  }

  /// Update a message's text.
  @override
  Future<void> updateMessage(
    String roomId,
    String messageId,
    String newText,
  ) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .collection(_messagesCollection)
            .doc(messageId)
            .update({
              FirestoreConstants.textField: newText,
              FirestoreConstants.editedAtField: Timestamp.now(),
            });

        // Update room if this is the last message
        await _updateRoomIfLastMessage(roomId, messageId, newText);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error updating message: $error', tag: _tag),
    );
  }

  /// Delete a single message.
  @override
  Future<void> deleteMessage(String roomId, String messageId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .collection(_messagesCollection)
            .doc(messageId)
            .delete();
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error deleting message: $error', tag: _tag),
    );
  }

  /// Batch delete multiple messages.
  @override
  Future<void> deleteMessages(String roomId, List<String> messageIds) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        // Firestore batch limit is 500
        final chunks = _chunkList(messageIds, 500);
        for (final chunk in chunks) {
          final batch = _firestore.batch();
          for (final messageId in chunk) {
            batch.delete(
              _firestore
                  .collection(_roomsCollection)
                  .doc(roomId)
                  .collection(_messagesCollection)
                  .doc(messageId),
            );
          }
          await batch.commit();
        }
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error deleting messages: $error', tag: _tag),
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  /// Build Firestore document data from a Message.
  Map<String, dynamic> _buildMessageData(Message message) {
    return {
      FirestoreConstants.senderIdField: message.senderId,
      'type': message.type.toJson(),
      FirestoreConstants.textField: message.text,
      if (message.mediaUrl != null) 'media_url': message.mediaUrl,
      if (message.replyToMessageId != null)
        'replyToMessageId': message.replyToMessageId,
      if (message.replyToMessage != null)
        'replyToMessage': message.replyToMessage!.toJson(),
      FirestoreConstants.timestampField: FieldValue.serverTimestamp(),
      if (message.metadata != null) 'metadata': message.metadata,
    };
  }

  /// Get preview text for last message display.
  String _getLastMessagePreview(Message message) {
    return switch (message.type) {
      MessageType.text => message.text,
      MessageType.callLog => message.text.isNotEmpty ? message.text : 'Call',
      _ => message.type.toJson(),
    };
  }

  /// Update room's lastMessage if this message is the most recent.
  Future<void> _updateRoomIfLastMessage(
    String roomId,
    String messageId,
    String newText,
  ) async {
    final messagesQuery = await _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .collection(_messagesCollection)
        .orderBy(FirestoreConstants.timestampField, descending: true)
        .limit(1)
        .get();

    if (messagesQuery.docs.isNotEmpty &&
        messagesQuery.docs.first.id == messageId) {
      await _roomRepository.updateLastMessage(
        roomId: roomId,
        lastMessage: newText,
      );
    }
  }

  /// Chunk a list into smaller lists.
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}

/// Utility for generating call status display text.
class CallStatusText {
  const CallStatusText._();

  /// Get display text for a call status.
  static String fromStatus(String status) {
    return switch (status) {
      'missed' || 'rejected' || 'cancelled' => 'Missed call',
      'ended' => 'Call ended',
      _ => 'Call ended',
    };
  }
}
