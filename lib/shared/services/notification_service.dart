import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

/// Handles local notification display and management
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;
  NotificationService._internal();

  late FlutterLocalNotificationsPlugin _localNotifications;
  final AppLogger _log = sl<AppLogger>();
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  static const String _tag = 'NotificationService';

  /// Initialize local notifications plugin
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    // Create the initialization future and store it immediately (atomic operation)
    _initializationFuture = _performInitialization();

    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _performInitialization() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    await ErrorHandler.handle<void>(
      operation: () async {
        // Android initialization
        const androidInitSettings = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );

        // iOS initialization
        const iosInitSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          defaultPresentAlert: true, // Show alert when app is in foreground
          defaultPresentBadge: true, // Show badge when app is in foreground
          defaultPresentSound: true, // Play sound when app is in foreground
        );

        final initSettings = InitializationSettings(
          android: androidInitSettings,
          iOS: iosInitSettings,
        );

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _handleNotificationTap,
          onDidReceiveBackgroundNotificationResponse:
              _handleBackgroundNotificationTap,
        );

        // Create notification channels for Android
        await _createNotificationChannels();

        _isInitialized = true;
        _log.info('Notification Service initialized successfully', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error initializing: $error', tag: _tag),
    );
  }

  /// Create notification channels for Android 8+
  Future<void> _createNotificationChannels() async {
    // Only create channels on Android - iOS doesn't use/support them
    // Skip on web platform entirely
    if (kIsWeb) {
      return;
    }

    await ErrorHandler.handle<void>(
      operation: () async {
        if (!Platform.isAndroid) {
          return;
        }

        final androidPlugin = AndroidFlutterLocalNotificationsPlugin();

        // Call notifications channel
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            'calls',
            'Calls',
            description: 'Notifications for incoming calls',
            importance: Importance.max,
            sound: const RawResourceAndroidNotificationSound('ringtone'),
            vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
            enableVibration: true,
          ),
        );

        // Messages channel
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            'messages',
            'Messages',
            description: 'Notifications for new messages',
            importance: Importance.high,
            sound: const RawResourceAndroidNotificationSound('ringtone1'),
            enableVibration: true,
          ),
        );

        // General notifications channel
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            'general',
            'General',
            description: 'General notifications',
            importance: Importance.defaultImportance,
            sound: const RawResourceAndroidNotificationSound('ringtone1'),
          ),
        );

        _log.info('Notification channels created', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error creating notification channels: $error', tag: _tag),
    );
  }

  /// Show a notification with optional custom details
  Future<void> showNotification({
    required String title,
    required String body,
    String? channelId,
    Map<String, String>? payload,
    int notificationId = 1,
    String? groupKey,
  }) async {
    if (!_isInitialized) {
      _log.error('ERROR: Notification Service not initialized', tag: _tag);
      return;
    }

    await ErrorHandler.handle<void>(
      operation: () async {
        final channelToUse = channelId ?? 'general';

        final androidDetails = AndroidNotificationDetails(
          channelToUse,
          'Default Channel',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          number: notificationId,
          // Group notifications by type for better organization
          groupKey: groupKey,
          setAsGroupSummary: false,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'default_action',
              'Open',
              cancelNotification: true,
            ),
          ],
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _localNotifications.show(
          notificationId,
          title,
          body,
          notificationDetails,
          payload: payload != null ? Uri(queryParameters: payload).query : null,
        );

        _log.info('Notification shown: $title', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error showing notification: $error', tag: _tag),
    );
  }

  /// Show notification for incoming call
  Future<void> showIncomingCallNotification({
    required String callerName,
    required String callerId,
    required String roomId,
    bool isVideo = true,
  }) async {
    await showNotification(
      title: 'Incoming ${isVideo ? 'Video' : 'Audio'} Call',
      body: 'Call from $callerName',
      channelId: 'calls',
      groupKey: 'com.greenhive.CALLS',
      payload: {
        'type': 'incoming_call',
        'caller_id': callerId,
        'room_id': roomId,
        'is_video': isVideo.toString(),
      },
    );
  }

  /// Show notification for new message
  Future<void> showNewMessageNotification({
    required String senderName,
    required String senderId,
    required String message,
    required String roomId,
  }) async {
    await showNotification(
      title: 'New message from $senderName',
      body: message,
      channelId: 'messages',
      groupKey: 'com.greenhive.MESSAGES',
      payload: {
        'type': 'new_message',
        'sender_id': senderId,
        'room_id': roomId,
      },
    );
  }

  /// Show notification for expert request
  Future<void> showExpertRequestNotification({
    required String requesterName,
    required String requesterId,
    required String requestId,
  }) async {
    await showNotification(
      title: 'New Expert Request',
      body: '$requesterName is requesting your expertise',
      channelId: 'general',
      groupKey: 'com.greenhive.EXPERT_REQUESTS',
      payload: {
        'type': 'expert_request',
        'requester_id': requesterId,
        'request_id': requestId,
      },
    );
  }

  /// Handle notification tap when app is in foreground/background
  static void _handleNotificationTap(
    NotificationResponse notificationResponse,
  ) {
    final log = sl<AppLogger>();
    log.debug(
      'Notification tapped: ${notificationResponse.id} | Payload: ${notificationResponse.payload}',
      tag: _tag,
    );

    // Parse payload and handle navigation
    if (notificationResponse.payload != null) {
      final params = Uri(query: notificationResponse.payload).queryParameters;
      final type = params['type'];

      switch (type) {
        case 'incoming_call':
          // Navigate to call screen
          break;
        case 'new_message':
          // Navigate to chat screen
          break;
        case 'expert_request':
          // Navigate to request details
          break;
        default:
          log.warning('Unknown notification type: $type', tag: _tag);
      }
    }
  }

  /// Handle background notification tap (top-level callback)
  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationTap(
    NotificationResponse notificationResponse,
  ) {
    _handleNotificationTap(notificationResponse);
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _localNotifications.cancel(notificationId);
      },
      onError: (error) =>
          _log.error('Error cancelling notification: $error', tag: _tag),
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _localNotifications.cancelAll();
        _log.info('All notifications cancelled', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error cancelling all notifications: $error', tag: _tag),
    );
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return ErrorHandler.handle(
      operation: () async {
        return await _localNotifications.pendingNotificationRequests();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting pending notifications: $error', tag: _tag),
    );
  }

  /// Clear the app badge (iOS app icon badge number)
  Future<void> clearBadge() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (!kIsWeb && Platform.isIOS) {
          // Clear badge by resetting it to 0 via platform channel
          const platform = MethodChannel('com.greenhive.app/notifications');
          await platform.invokeMethod('clearBadge');
        }
      },
      onError: (error) => _log.error('Error clearing badge: $error', tag: _tag),
    );
  }

  /// Set the app badge to a specific count (iOS only)
  Future<void> setBadge(int count) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        if (!kIsWeb && Platform.isIOS) {
          const platform = MethodChannel('com.greenhive.app/notifications');
          await platform.invokeMethod('setBadge', {'count': count});
        }
      },
      onError: (error) => _log.error('Error setting badge: $error', tag: _tag),
    );
  }

  /// Increment the app badge by the specified amount (iOS only)
  /// Returns the new badge count
  Future<int> incrementBadge([int count = 1]) async {
    return ErrorHandler.handle<int>(
      operation: () async {
        if (!kIsWeb && Platform.isIOS) {
          const platform = MethodChannel('com.greenhive.app/notifications');
          final result = await platform.invokeMethod<int>('incrementBadge', {
            'count': count,
          });
          return result ?? 0;
        }
        return 0;
      },
      fallback: 0,
      onError: (error) =>
          _log.error('Error incrementing badge: $error', tag: _tag),
    );
  }

  /// Get the current badge count (iOS only)
  Future<int> getBadge() async {
    return ErrorHandler.handle<int>(
      operation: () async {
        if (!kIsWeb && Platform.isIOS) {
          const platform = MethodChannel('com.greenhive.app/notifications');
          final result = await platform.invokeMethod<int>('getBadge');
          return result ?? 0;
        }
        return 0;
      },
      fallback: 0,
      onError: (error) => _log.error('Error getting badge: $error', tag: _tag),
    );
  }
}
