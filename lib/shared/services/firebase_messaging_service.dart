import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:securityexperts_app/shared/services/pending_notification_handler.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/features/calling/services/incoming_call_manager.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'notification_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';

/// Handles Firebase Cloud Messaging (FCM) setup and message processing
///
/// Access via service locator: `sl<FirebaseMessagingService>()`
class FirebaseMessagingService {
  FirebaseMessagingService({FirebaseMessaging? firebaseMessaging})
    : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  static bool _handlersRegistered = false;
  static final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'FCMService';

  void _registerHandlersOnce() {
    // Handlers are registered synchronously
    // The singleton pattern ensures this only runs once, but due to hot reload
    // and widget rebuilds, we use a guard to prevent re-registration
    if (!_handlersRegistered) {
      // Set up message handlers once when singleton is created
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _handlersRegistered = true;
    }
  }

  final FirebaseMessaging _firebaseMessaging;

  // Use service locator for dependencies
  UserRepository get _userRepository => sl<UserRepository>();
  NotificationService get _notificationService => sl<NotificationService>();

  static const String _prefsFcmTokenKey = 'cached_fcm_token';

  // Stream controllers for message events
  final _messageController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageController.stream;

  String? _fcmToken;
  String? _currentUserId;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;
  StreamSubscription<String>? _tokenRefreshSubscription;

  // Track processed message IDs to prevent duplicate handling
  final Set<String> _processedMessageIds = {};
  static const int _maxProcessedMessages = 100;

  /// Initialize Firebase Messaging service
  /// Call this once when app starts (in main.dart or splash screen)
  Future<void> initialize(String userId) async {
    // If initialization is already in progress, wait for it to complete
    if (_initializationFuture != null) {
      _log.debug(
        'Firebase Messaging initialization already in progress, waiting...',
        tag: _tag,
      );
      await _initializationFuture;
      return;
    }

    // Check if already initialized for the same user
    if (_isInitialized && _currentUserId == userId) {
      // Even if initialized, ensure token is saved to Firestore
      // This handles cases where token was cached but not saved to Firestore
      if (_fcmToken != null) {
        await _saveFcmTokenToFirestore(userId, _fcmToken!);
      }
      return;
    }

    // Set the future immediately to block concurrent calls (atomic operation)
    _currentUserId = userId;
    _initializationFuture = _performInitialization(userId);

    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _performInitialization(String userId) async {
    // Register handlers once (moved from constructor since we removed factory pattern)
    _registerHandlersOnce();

    _log.info('Initializing FCM', tag: _tag);

    await ErrorHandler.handle<void>(
      operation: () async {
        // Ensure notification service is initialized first
        await _notificationService.initialize();

        // Request notification permissions
        await _requestNotificationPermission();

        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();

        if (_fcmToken == null) {
          _log.warning('FCM token is null', tag: _tag);
        }

        // Persist token to backend profile
        if (_fcmToken != null) {
          await _saveFcmTokenToFirestore(userId, _fcmToken!);
        } else {
          _log.warning('Cannot save FCM token - token is null', tag: _tag);
        }

        // Set up token refresh listener (only once per instance)
        _tokenRefreshSubscription ??= _firebaseMessaging.onTokenRefresh.listen((
          newToken,
        ) {
          _fcmToken = newToken;
          if (_currentUserId != null) {
            _saveFcmTokenToFirestore(_currentUserId!, newToken);
          } else {
            _log.warning(
              'FCM token refreshed but no current user ID',
              tag: _tag,
            );
          }
        });

        _isInitialized = true;
        _log.info('FCM initialized successfully', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error initializing FCM: $error', tag: _tag),
    );
  }

  /// Request notification permissions from user
  Future<void> _requestNotificationPermission() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        NotificationSettings settings = await _firebaseMessaging
            .requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              carPlay: false,
              criticalAlert: false,
              provisional: false,
              sound: true,
            );

        _log.debug(
          'Notification permission: ${settings.authorizationStatus}',
          tag: _tag,
        );
      },
      onError: (error) => _log.error(
        'Error requesting notification permission: $error',
        tag: _tag,
      ),
    );
  }

  /// Persist FCM token by adding to the user's profile in Firestore
  Future<void> _saveFcmTokenToFirestore(String userId, String token) async {
    try {
      final cachedToken = await _getCachedFcmToken();

      if (cachedToken != null && cachedToken == token) {
        return; // Token unchanged, skip update
      }

      final fb_auth.User? fbUser = sl<fb_auth.FirebaseAuth>().currentUser;
      if (fbUser == null) {
        _log.warning(
          'No authenticated user found; cannot save FCM token',
          tag: _tag,
        );
        return;
      }

      // Use UserRepository to add the FCM token, passing old token for replacement
      await _userRepository.addFcmToken(token, oldToken: cachedToken);
      await _cacheFcmToken(token);
    } catch (e, stackTrace) {
      _log.error('Error saving FCM token', tag: _tag, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Handle messages when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final messageId = message.messageId;

    // Atomic check and add to prevent duplicate processing
    // This check happens synchronously before any async operations
    if (messageId != null) {
      if (_processedMessageIds.contains(messageId)) {
        return; // Skip duplicate message
      }
      // Immediately add to set before any await calls
      _processedMessageIds.add(messageId);
      // Keep the set from growing too large
      if (_processedMessageIds.length > _maxProcessedMessages) {
        final oldestId = _processedMessageIds.first;
        _processedMessageIds.remove(oldestId);
      }
    }

    _log.debug('Handling foreground message', tag: _tag);

    // Firebase will automatically display the notification banner on iOS when app is in foreground
    // (because we enabled setForegroundNotificationPresentationOptions in main.dart)

    // Handle incoming call notifications immediately to show dialog without Firestore delay
    final notificationType = message.data['type'] as String?;
    if (notificationType == 'incoming_call') {
      _handleIncomingCallFromFcm(message.data);
    }

    // Increment badge count for iOS on new notifications
    // Only increment for certain notification types (not calls, which are transient)
    if (notificationType != 'incoming_call' &&
        notificationType != 'call_ended') {
      await _notificationService.incrementBadge();
    }

    // Add to message stream for UI to react
    _messageController.add(message);
  }

  /// Handle notification tap (when app is background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    _log.debug('Notification tapped: ${message.messageId}', tag: _tag);

    // Handle deep linking based on notification data
    _handleDeepLink(message.data);

    // Add to message stream
    _messageController.add(message);
  }

  /// Handle incoming call notification from FCM
  /// This triggers the call dialog immediately without waiting for Firestore
  void _handleIncomingCallFromFcm(Map<String, dynamic> data) {
    final callerId = data['caller_id'] as String?;
    final roomId = data['room_id'] as String?;
    final callerName = data['caller_name'] as String? ?? 'Unknown Caller';
    final isVideoStr = data['is_video'] as String?;
    final isVideo = isVideoStr == 'true' || isVideoStr == '1';

    if (callerId == null || roomId == null) {
      _log.warning(
        'Missing call data in FCM: callerId=$callerId, roomId=$roomId',
        tag: _tag,
      );
      return;
    }

    _log.debug('Triggering incoming call dialog from FCM', tag: _tag);

    // Trigger the IncomingCallManager to show the call dialog
    sl<IncomingCallManager>().showIncomingCall({
      'caller_id': callerId,
      'room_id': roomId,
      'caller_name': callerName,
      'is_video': isVideo,
    });
  }

  /// Handle deep linking from notification
  void _handleDeepLink(Map<String, dynamic> data) {
    ErrorHandler.handleSync(
      operation: () {
        final type = data['type'] as String?;

        _log.debug('Deep link: type=$type, data=$data', tag: _tag);

        // Use the navigator key from PendingNotificationHandler
        final context = PendingNotificationHandler.navigatorKey.currentContext;
        if (context == null) {
          _log.debug(
            'No navigation context available, storing for later',
            tag: _tag,
          );
          // Store as pending if no context available
          return;
        }

        // Delegate to centralized navigation handler
        PendingNotificationHandler.handleNotificationNavigation(context, data);
      },
      onError: (error) =>
          _log.error('Error handling deep link: $error', tag: _tag),
    );
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;
  /*
  /// Test/debug method to simulate receiving a notification (for simulator testing)
  Future<void> simulateNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    developer.log('Simulating notification: $title', name: 'FCMService');
    await _notificationService.showNotification(
      title: title,
      body: body,
      payload: data,
    );
  }
  */
  Future<String?> _getCachedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsFcmTokenKey);
  }

  Future<void> _cacheFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsFcmTokenKey, token);
  }

  /// Clear cached FCM token
  Future<void> _clearCachedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsFcmTokenKey);
  }

  /// Remove FCM token on logout to prevent stale notifications
  /// Call this before signing out the user
  Future<void> removeTokenOnLogout() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final token = _fcmToken;

        if (token != null) {
          // Use UserRepository to remove the FCM token
          await _userRepository.removeFcmToken(token);

          // Delete the token from FCM to stop receiving notifications
          await _firebaseMessaging.deleteToken();
        }

        // Always clear local state on logout
        await _clearCachedFcmToken();
        _fcmToken = null;

        // Reset initialization state so next login will re-initialize
        _isInitialized = false;
        _currentUserId = null;

        _log.info('FCM cleanup completed on logout', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error removing FCM token: $error', tag: _tag),
    );
  }

  /// Subscribe to a topic for group notifications
  Future<void> subscribeToTopic(String topic) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _firebaseMessaging.subscribeToTopic(topic);
        _log.debug('Subscribed to topic: $topic', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error subscribing to topic: $error', tag: _tag),
    );
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        await _firebaseMessaging.unsubscribeFromTopic(topic);
        _log.debug('Unsubscribed from topic: $topic', tag: _tag);
      },
      onError: (error) =>
          _log.error('Error unsubscribing from topic: $error', tag: _tag),
    );
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _messageController.close();
    _isInitialized = false;
    _currentUserId = null;
    _log.debug('Firebase Messaging Service disposed', tag: _tag);
  }
}

/// Top-level function to handle background messages (runs in isolate)
/// This MUST be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  sl<AppLogger>().debug(
    'Handling background message: ${message.messageId}',
    tag: 'FCMService',
  );

  // Initialize notification service for background
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Display local notification
  if (message.notification != null) {
    // Cast data to Map<String, String> for notification payload
    final payload = message.data.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    await notificationService.showNotification(
      title: message.notification!.title ?? 'Notification',
      body: message.notification!.body ?? '',
      payload: payload,
    );
  }
}
