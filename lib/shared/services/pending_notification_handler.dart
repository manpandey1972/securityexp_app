import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:greenhive_app/features/calling/pages/call_history_page.dart';
import 'package:greenhive_app/features/chat/pages/chat_conversation_page.dart';
import 'package:greenhive_app/features/support/pages/ticket_detail_page.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Handles pending notifications that were tapped while app was terminated.
///
/// When the app is terminated and user taps a notification, we need to:
/// 1. Store the message before UI is ready (in main.dart)
/// 2. Process it once we have a navigation context (in splash/home)
class PendingNotificationHandler {
  static RemoteMessage? _pendingMessage;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'PendingNotificationHandler';

  /// Store a pending message from cold start
  static void setPendingMessage(RemoteMessage? message) {
    _pendingMessage = message;
    if (message != null) {
      _log.debug('Stored pending message: ${message.messageId}', tag: _tag);
    }
  }

  /// Check if there's a pending message
  static bool get hasPendingMessage => _pendingMessage != null;

  /// Get and clear the pending message
  static RemoteMessage? consumePendingMessage() {
    final message = _pendingMessage;
    _pendingMessage = null;
    return message;
  }

  /// Process the pending notification with navigation context
  /// Call this after the app is fully initialized (e.g., in home page)
  static void processPendingNotification(BuildContext context) {
    final message = consumePendingMessage();
    if (message == null) return;

    _log.debug('Processing pending message: ${message.messageId}', tag: _tag);
    _log.debug('Data: ${message.data}', tag: _tag);

    // Navigate based on notification data
    handleNotificationNavigation(context, message.data);
  }

  /// Handle navigation based on notification data
  /// This is the central place for all notification-based navigation
  static void handleNotificationNavigation(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;

    _log.debug('Handling navigation for type: $type', tag: _tag);

    switch (type) {
      case 'incoming_call':
        _handleIncomingCall(context, data);
        break;
      case 'new_message':
        _handleNewMessage(context, data);
        break;
      case 'expert_request':
        _handleExpertRequest(context, data);
        break;
      case 'missed_call':
        _handleMissedCall(context, data);
        break;
      case 'support_message':
      case 'support_status_change':
        _handleSupportNotification(context, data);
        break;
      default:
        _log.warning('Unknown notification type: $type', tag: _tag);
    }
  }

  static void _handleIncomingCall(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final callerId = data['caller_id'] as String?;
    final roomId = data['room_id'] as String?;
    final isVideo = data['is_video'] == 'true';

    if (callerId == null || roomId == null) {
      _log.warning('Missing call data', tag: _tag);
      return;
    }

    _log.debug(
      'Navigating to call: room=$roomId, caller=$callerId, video=$isVideo',
      tag: _tag,
    );

    // Note: By the time user taps a call notification from terminated state,
    // the call is likely already ended or answered elsewhere.
    // Navigate to call history to see the missed call
    _navigateToCallHistory(context);
  }

  static void _handleNewMessage(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final senderId = data['sender_id'] as String?;
    final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
    final senderName = data['sender_name'] as String? ?? 'User';

    if (senderId == null && roomId == null) {
      _log.warning('Missing message data', tag: _tag);
      return;
    }

    // Navigate to chat conversation
    // Using dynamic import to avoid circular dependencies
    _navigateToChatConversation(context, senderId ?? '', senderName);
  }

  static void _handleExpertRequest(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final requesterId = data['requester_id'] as String?;
    final requestId = data['request_id'] as String?;

    _log.debug(
      'Expert request: requester=$requesterId, request=$requestId',
      tag: _tag,
    );

    // Navigate to chat with the requester since expert requests are handled via chat
    if (requesterId != null) {
      final requesterName = data['requester_name'] as String? ?? 'User';
      _navigateToChatConversation(context, requesterId, requesterName);
    }
  }

  static void _handleMissedCall(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final callerId = data['caller_id'] as String?;
    final callerName = data['caller_name'] as String? ?? 'Unknown';

    _log.debug('Missed call from: $callerName ($callerId)', tag: _tag);

    // Navigate to call history to see the missed call
    _navigateToCallHistory(context);
  }

  static void _navigateToCallHistory(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CallHistoryPage()));
  }

  static void _navigateToChatConversation(
    BuildContext context,
    String partnerId,
    String partnerName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          partnerId: partnerId,
          partnerName: partnerName,
        ),
      ),
    );
  }

  static void _handleSupportNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final ticketId = data['ticketId'] as String?;
    final ticketNumber = data['ticketNumber'] as String?;

    if (ticketId == null) {
      _log.warning('Missing ticketId in support notification', tag: _tag);
      return;
    }

    _log.debug(
      'Navigating to support ticket: id=$ticketId, number=$ticketNumber',
      tag: _tag,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
    );
  }
}
