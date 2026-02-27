import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/config/remote_config_service.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';

typedef OnMessagesUpdated = void Function(List<Message> messages);
typedef OnError = void Function(String error);

class ChatStreamService {
  final String roomId;
  final ChatMessageRepository _messageRepository;
  final FirebaseAuth _auth;
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'ChatStreamService';

  // Stream subscriptions
  StreamSubscription<List<Message>>? _messagesSubscription;

  // Callbacks
  OnMessagesUpdated? onMessagesUpdated;
  OnError? onError;

  // State
  final List<Message> _messages = [];

  ChatStreamService({
    required this.roomId,
    ChatMessageRepository? messageRepository,
    FirebaseAuth? auth,
  }) : _messageRepository = messageRepository ?? sl<ChatMessageRepository>(),
       _auth = auth ?? FirebaseAuth.instance;

  List<Message> get messages => _messages;

  /// Initialize message stream
  void startListening() {
    ErrorHandler.handleSync(
      operation: () {
        _subscribeToMessages();
      },
      onError: (error) =>
          onError?.call('Error starting message streams: $error'),
    );
  }

  /// Subscribe to messages
  void _subscribeToMessages() {
    final batchSize = sl<RemoteConfigService>().messageBatchSize;
    final stopwatch = Stopwatch()..start();
    _messagesSubscription = _messageRepository
        .getMessagesStream(roomId, limit: batchSize)
        .listen(
          (streamMessages) {
            ErrorHandler.handleSync(
              operation: () {
                _log.debug(
                  'Stream emitted ${streamMessages.length} messages in ${stopwatch.elapsedMilliseconds}ms',
                  tag: _tag,
                );
                _messages.clear();
                _messages.addAll(streamMessages);
                onMessagesUpdated?.call(_messages);
                _log.debug(
                  'Callback completed in ${stopwatch.elapsedMilliseconds}ms',
                  tag: _tag,
                );
              },
              onError: (error) =>
                  onError?.call('Error loading messages: $error'),
            );
          },
          onError: (error) {
            onError?.call('Messages stream error: $error');
          },
        );
  }

  /// Dispose all subscriptions
  void dispose() {
    _messagesSubscription?.cancel();
    _messages.clear();
  }

  /// Get unread count for this chat
  Future<int> getUnreadCount() async {
    return ErrorHandler.handle(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return 0;

        final roomDoc = await FirestoreInstance().db
            .collection('chat_rooms')
            .doc(roomId)
            .get();
        if (!roomDoc.exists) return 0;

        final unreadMap =
            roomDoc.data()?['unreadCounts'] as Map<String, dynamic>?;
        return unreadMap?[currentUser.uid] as int? ?? 0;
      },
      fallback: 0,
      onError: (error) => onError?.call('Error getting unread count: $error'),
    );
  }

  /// Mark chat as read
  Future<void> markAsRead() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;

        await FirestoreInstance().db.collection('chat_rooms').doc(roomId).update({
          'unreadCounts.${currentUser.uid}': 0,
        });
      },
      onError: (error) => onError?.call('Error marking chat as read: $error'),
    );
  }

  /// Get message count
  Future<int> getMessageCount() async {
    return ErrorHandler.handle(
      operation: () async {
        final query = await FirestoreInstance().db
            .collection('chat_rooms')
            .doc(roomId)
            .collection('messages')
            .count()
            .get();

        return query.count ?? 0;
      },
      fallback: 0,
      onError: (error) => onError?.call('Error getting message count: $error'),
    );
  }

  /// Search messages by text
  Future<List<Message>> searchMessages(String query) async {
    return ErrorHandler.handle(
      operation: () async {
        // Simple client-side search
        final results = _messages
            .where(
              (msg) => msg.text.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

        return results;
      },
      fallback: [],
      onError: (error) => onError?.call('Error searching messages: $error'),
    );
  }
}
