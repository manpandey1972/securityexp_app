import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/constants.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_room_repository.dart';
import 'package:securityexperts_app/data/repositories/interfaces/repository_interfaces.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/features/chat/services/encryption_service.dart';

/// Repository for chat message operations.
/// Handles message CRUD, pagination, and real-time streams.
class ChatMessageRepository implements IChatMessageRepository {
  final FirebaseFirestore _firestore;
  final ChatRoomRepository _roomRepository;
  final EncryptionService? _encryptionService;
  final AppLogger _log = sl<AppLogger>();
  final AnalyticsService _analytics = sl<AnalyticsService>();

  static const String _tag = 'ChatMessageRepo';
  static const String _roomsCollection = FirestoreInstance.roomsCollection;
  static const String _messagesCollection =
      FirestoreInstance.messagesCollection;

  ChatMessageRepository({
    FirebaseFirestore? firestore,
    required ChatRoomRepository roomRepository,
    EncryptionService? encryptionService,
  }) : _firestore = firestore ?? FirestoreInstance().db,
       _roomRepository = roomRepository,
       _encryptionService = encryptionService;

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
        .asyncMap<List<Message>>((snapshot) async {
          try {
            final docs = snapshot.docs.where((doc) {
              final data = doc.data();
              return data.containsKey(FirestoreConstants.senderIdField) &&
                  data[FirestoreConstants.senderIdField]
                      .toString()
                      .isNotEmpty;
            });
            final messages = await Future.wait(
              docs.map((doc) => _parseDocument(doc, roomId)),
            );
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

            final messages = await Future.wait(
              snapshot.docs.map((doc) => _parseDocument(doc, roomId)),
            );

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
        
        final messages = await Future.wait(
          snapshot.docs.map((doc) => _parseDocument(doc, roomId)),
        );

        trace.putAttribute('doc_count', snapshot.docs.length.toString());
        await trace.stop();

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

              Map<String, dynamic> messageData;
              final bool encrypted;

              if (_shouldEncrypt(message)) {
                // E2EE: Encrypt the message using per-room key
                final content = _messageToDecryptedContent(message);

                final encryptedMessage = await _encryptionService!.encryptMessage(
                  roomId: roomId,
                  senderId: message.senderId,
                  messageType: message.type.toJson(),
                  content: content,
                );

                messageData = encryptedMessage.toJson();
                messageData['sender_id'] = message.senderId;
                encrypted = true;
              } else {
                messageData = _buildMessageData(message);
                encrypted = false;
              }

              await docRef.set(messageData);
              
              await firestoreTrace.stop();

              // Update room's last message
              final lastMessageText = encrypted
                  ? '\u{1F512} Encrypted message'
                  : _getLastMessagePreview(message);
              await _roomRepository.updateLastMessage(
                roomId: roomId,
                lastMessage: lastMessageText,
              );

              return message.copyWith(
                id: docRef.id,
                isEncrypted: encrypted,
              );
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

  /// Send an encrypted media message directly to Firestore.
  ///
  /// The message has already been encrypted via Signal Protocol in UploadManager.
  /// This writes the encrypted payload and updates the room's last message.
  @override
  Future<void> sendEncryptedMediaMessage({
    required String roomId,
    required EncryptedMessage encryptedMessage,
    required String senderId,
    required MessageType messageType,
  }) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final messagesRef = _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .collection(_messagesCollection);

        final docRef = messagesRef.doc();

        final data = {
          ...encryptedMessage.toJson(),
          'sender_id': senderId,
          'timestamp': FieldValue.serverTimestamp(),
          'type': messageType.toJson(),
        };

        await docRef.set(data);

        // Update room last message metadata
        await _roomRepository.updateLastMessage(
          roomId: roomId,
          lastMessage: '\u{1F512} Encrypted message',
        );

        _log.info('Encrypted media message sent: ${docRef.id}', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error sending encrypted media message: $error',
              tag: _tag),
    );
  }

  /// Update a message's text.
  /// For encrypted messages, re-encrypts the new content.
  @override
  Future<void> updateMessage(
    String roomId,
    String messageId,
    String newText,
  ) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final docRef = _firestore
            .collection(_roomsCollection)
            .doc(roomId)
            .collection(_messagesCollection)
            .doc(messageId);

        // Check if the message is encrypted
        if (_encryptionService != null) {
          final doc = await docRef.get();
          if (doc.exists && doc.data()?.containsKey('ciphertext') == true) {
            // Re-encrypt the edited message
            final senderId = doc.data()!['sender_id'] as String;
            final content = DecryptedContent(text: newText);

            final encryptedMessage = await _encryptionService.encryptMessage(
              roomId: roomId,
              senderId: senderId,
              messageType: doc.data()!['type'] as String? ?? 'text',
              content: content,
            );

            await docRef.update({
              'ciphertext': encryptedMessage.ciphertext,
              'iv': encryptedMessage.iv,
              'edited_at': Timestamp.now(),
            });

            await _updateRoomIfLastMessage(
              roomId,
              messageId,
              '\u{1F512} Encrypted message',
            );
            return;
          }
        }

        // Plaintext update (unencrypted or no encryption service)
        await docRef.update({
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
  // E2EE HELPERS
  // =========================================================================

  /// Whether a message should be encrypted.
  /// System messages are excluded from encryption.
  bool _shouldEncrypt(Message message) {
    if (message.type == MessageType.system) return false;
    return _encryptionService != null;
  }

  /// Convert a [Message] to [DecryptedContent] for encryption.
  DecryptedContent _messageToDecryptedContent(Message message) {
    return DecryptedContent(
      text: message.text.isNotEmpty ? message.text : null,
      mediaUrl: message.mediaUrl,
      replyToMessageId: message.replyToMessageId,
      metadata: message.metadata,
    );
  }

  /// Parse a Firestore document, decrypting if it's an encrypted message.
  ///
  /// Handles three cases:
  /// - No `ciphertext` field → plaintext message, parse normally
  /// - `encryption_version` == 1 (old Signal Protocol) → unrecoverable,
  ///   show fallback without attempting decryption
  /// - `encryption_version` == 2 (per-room AES-256-GCM) → decrypt
  /// Parse and (optionally) decrypt a single Firestore message document.
  ///
  /// Note: `compute()` / `Isolate.run()` is not used here because
  /// [EncryptionService.decryptMessage] depends on [RoomKeyService] which
  /// holds a Firestore connection — instances with platform channels cannot
  /// be transferred to a separate isolate.  The raw AES-GCM operation itself
  /// completes in microseconds, so the main-isolate cost is negligible.
  /// The async `Future.wait` in the calling code already parallelises I/O
  /// across all messages in a snapshot.
  Future<Message> _parseDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String roomId,
  ) async {
    final data = doc.data();

    if (!data.containsKey('ciphertext') || _encryptionService == null) {
      // Plaintext message or no encryption service available
      return Message.fromJson({...data, 'id': doc.id});
    }

    final version = data['encryption_version'] as int? ?? 1;
    if (version < 2) {
      // Old Signal Protocol messages — keys have been deleted and
      // these cannot be recovered. Show a clear fallback.
      return Message(
        id: doc.id,
        senderId: data['sender_id'] as String? ?? '',
        type: MessageTypeExtension.fromJson(data['type'] as String? ?? 'text'),
        text: '\u{1F512} Message from previous encryption protocol',
        timestamp: (data['timestamp'] as Timestamp?) ?? Timestamp.now(),
        isEncrypted: true,
        decryptionFailed: true,
      );
    }

    return _decryptToMessage(data, doc.id, roomId);
  }

  /// Decrypt an encrypted Firestore document into a [Message].
  /// Returns a fallback message on decryption failure.
  Future<Message> _decryptToMessage(
    Map<String, dynamic> data,
    String docId,
    String roomId,
  ) async {
    try {
      final encryptedMessage = EncryptedMessage.fromJson({...data, 'id': docId});
      final content = await _encryptionService!.decryptMessage(
        roomId: roomId,
        message: encryptedMessage,
      );

      return Message(
        id: docId,
        senderId: encryptedMessage.senderId,
        type: MessageTypeExtension.fromJson(encryptedMessage.type),
        text: content.text ?? '',
        mediaUrl: content.mediaUrl,
        replyToMessageId: content.replyToMessageId,
        timestamp: encryptedMessage.timestamp,
        metadata: content.metadata,
        isEncrypted: true,
        mediaKey: content.mediaKey,
        mediaHash: content.mediaHash,
        mediaType: content.mediaType,
        mediaSize: content.mediaSize,
        fileName: content.fileName,
      );
    } catch (e) {
      _log.error('Failed to decrypt message $docId: $e', tag: _tag);
      return Message(
        id: docId,
        senderId: data['sender_id'] as String? ?? '',
        type: MessageTypeExtension.fromJson(data['type'] as String? ?? 'text'),
        text: '\u{1F512} Unable to decrypt this message',
        timestamp: (data['timestamp'] as Timestamp?) ?? Timestamp.now(),
        isEncrypted: true,
        decryptionFailed: true,
      );
    }
  }

  /// Whether E2EE is available for this repository instance.
  bool get isE2eeEnabled => _encryptionService != null;

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
