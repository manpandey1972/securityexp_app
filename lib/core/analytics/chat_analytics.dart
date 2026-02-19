import 'package:securityexperts_app/core/analytics/analytics_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Analytics events for chat feature.
///
/// Tracks messaging, media sharing, and conversation management.
class ChatAnalytics {
  static AnalyticsService get _analytics => sl<AnalyticsService>();

  /// User opened a chat conversation
  static Future<void> conversationOpened({
    int? messageCount,
  }) async {
    await _analytics.logEvent(
      'chat_open_conversation',
      parameters: {
        if (messageCount != null) 'message_count': messageCount,
      },
    );
    _analytics.logBreadcrumb('Chat', 'opened_conversation');
  }

  /// Message sent
  static Future<void> messageSent({
    required String messageType, // 'text', 'image', 'video', 'audio', 'file'
    bool hasReply = false,
    int? textLength,
  }) async {
    await _analytics.logEvent(
      'chat_send_message',
      parameters: {
        'message_type': messageType,
        'has_reply': hasReply,
        if (textLength != null) 'text_length': textLength,
      },
    );
  }

  /// Message received (only counts when user is in the conversation)
  static Future<void> messageReceived({
    required String messageType,
  }) async {
    await _analytics.logEvent(
      'chat_receive_message',
      parameters: {'message_type': messageType},
    );
  }

  /// Media viewed (image, video, audio played)
  static Future<void> mediaViewed({
    required String mediaType, // 'image', 'video', 'audio'
  }) async {
    await _analytics.logEvent(
      'chat_view_media',
      parameters: {'media_type': mediaType},
    );
  }

  /// Media downloaded
  static Future<void> mediaDownloaded({
    required String mediaType,
    required int sizeBytes,
  }) async {
    await _analytics.logEvent(
      'chat_download_media',
      parameters: {
        'media_type': mediaType,
        'size_kb': (sizeBytes / 1024).round(),
      },
    );
  }

  /// Media upload started
  static Future<void> mediaUploadStarted({
    required String mediaType,
    required int sizeBytes,
  }) async {
    await _analytics.logEvent(
      'chat_upload_start',
      parameters: {
        'media_type': mediaType,
        'size_kb': (sizeBytes / 1024).round(),
      },
    );
  }

  /// Media upload completed
  static Future<void> mediaUploadCompleted({
    required String mediaType,
    required int durationMs,
    required bool success,
  }) async {
    await _analytics.logEvent(
      'chat_upload_complete',
      parameters: {
        'media_type': mediaType,
        'duration_ms': durationMs,
        'success': success,
      },
    );
  }

  /// Message deleted
  static Future<void> messageDeleted({
    String? messageType,
  }) async {
    await _analytics.logEvent(
      'chat_delete_message',
      parameters: {
        if (messageType != null) 'message_type': messageType,
      },
    );
  }

  /// Message edited
  static Future<void> messageEdited() async {
    await _analytics.logEvent('chat_edit_message');
  }

  /// Message replied to
  static Future<void> messageReplied() async {
    await _analytics.logEvent('chat_reply_message');
  }

  /// Chat history cleared
  static Future<void> chatCleared() async {
    await _analytics.logEvent('chat_clear_history');
    _analytics.logBreadcrumb('Chat', 'cleared_history');
  }

  /// Chat/conversation deleted
  static Future<void> chatDeleted() async {
    await _analytics.logEvent('chat_delete_conversation');
    _analytics.logBreadcrumb('Chat', 'deleted_conversation');
  }

  /// Link in message tapped
  static Future<void> linkTapped() async {
    await _analytics.logEvent('chat_tap_link');
  }

  /// Voice message recorded
  static Future<void> voiceMessageRecorded({
    required int durationSeconds,
  }) async {
    await _analytics.logEvent(
      'chat_record_voice',
      parameters: {'duration_seconds': durationSeconds},
    );
  }
}
