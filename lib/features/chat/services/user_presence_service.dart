import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Service to manage user presence status in Firebase Realtime Database.
///
/// This service uses Firebase RTDB's `onDisconnect()` feature to automatically
/// set the user as offline when they disconnect (even if the app is killed).
///
/// The presence data is used by Cloud Functions to determine whether to send
/// push notifications - if the user is actively viewing a chat, notifications
/// for that chat are suppressed.
///
/// Usage:
/// ```dart
/// // Initialize on app start (after auth)
/// await presenceService.initialize();
///
/// // When entering a chat room
/// presenceService.enterChatRoom(roomId);
///
/// // When leaving a chat room
/// presenceService.leaveChatRoom();
///
/// // When app goes to background (called automatically via lifecycle)
/// presenceService.setAppInBackground();
///
/// // Cleanup on logout
/// await presenceService.dispose();
/// ```
class UserPresenceService {
  static const String _tag = 'UserPresenceService';

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  final AppLogger _logger;

  String? _currentChatRoomId;
  String? _userId; // Store userId to handle logout race condition
  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  bool _isInitialized = false;
  bool _isAppInForeground = true;

  UserPresenceService({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    AppLogger? logger,
  })  : _database = database ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _logger = logger ?? sl<AppLogger>();

  /// Current chat room the user is viewing (null if not in any chat)
  String? get currentChatRoomId => _currentChatRoomId;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize presence tracking.
  /// Call this after the user is authenticated.
  Future<void> initialize() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _logger.warning('Cannot initialize presence - no authenticated user', tag: _tag);
      return;
    }

    if (_isInitialized) {
      _logger.debug('Presence already initialized', tag: _tag);
      return;
    }

    // Store userId for later use (e.g., during logout when auth.currentUser is null)
    _userId = userId;

    try {
      final presenceRef = _database.ref('presence/$userId');
      final connectedRef = _database.ref('.info/connected');

      // Listen to connection state changes
      _connectionSubscription = connectedRef.onValue.listen((event) async {
        final isConnected = event.snapshot.value as bool? ?? false;

        if (isConnected) {
          _logger.debug('Connected to Firebase RTDB', tag: _tag);

          // Set up onDisconnect handler - this runs on Firebase servers
          // when the client disconnects (even if app is killed)
          await presenceRef.onDisconnect().set({
            'isOnline': false,
            'currentChatRoomId': null,
            'lastUpdated': ServerValue.timestamp,
          });

          // Set current presence as online
          await presenceRef.set({
            'isOnline': _isAppInForeground,
            'currentChatRoomId': _currentChatRoomId,
            'lastUpdated': ServerValue.timestamp,
          });

          _logger.debug(
            'Presence initialized: online=$_isAppInForeground, chatRoom=$_currentChatRoomId',
            tag: _tag,
          );
        } else {
          _logger.debug('Disconnected from Firebase RTDB', tag: _tag);
        }
      });

      _isInitialized = true;
      _logger.info('UserPresenceService initialized', tag: _tag);
    } catch (e) {
      _logger.error('Failed to initialize presence: $e', tag: _tag);
    }
  }

  /// Called when user enters a specific chat room.
  /// This updates presence so Cloud Functions know not to send push notifications
  /// for messages in this room.
  Future<void> enterChatRoom(String roomId) async {
    _currentChatRoomId = roomId;
    await _updatePresence();
    _logger.debug('Entered chat room: $roomId', tag: _tag);
  }

  /// Called when user leaves the current chat room.
  Future<void> leaveChatRoom() async {
    final previousRoom = _currentChatRoomId;
    _currentChatRoomId = null;
    await _updatePresence();
    _logger.debug('Left chat room: $previousRoom', tag: _tag);
  }

  /// Called when app comes to foreground.
  Future<void> setAppInForeground() async {
    _isAppInForeground = true;
    await _updatePresence();
    _logger.debug('App in foreground', tag: _tag);
  }

  /// Called when app goes to background.
  /// Note: This is best-effort - if the app is killed, onDisconnect() handles it.
  Future<void> setAppInBackground() async {
    _isAppInForeground = false;
    // Keep currentChatRoomId - user may be on chat screen when backgrounded
    // The isOnline: false flag is sufficient for Cloud Functions to send notifications
    await _updatePresence();
    _logger.debug('App in background, chatRoom=$_currentChatRoomId', tag: _tag);
  }

  /// Update presence in Firebase RTDB.
  Future<void> _updatePresence() async {
    // Don't update if service has been disposed
    if (!_isInitialized) return;
    
    final userId = _userId ?? _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final presenceRef = _database.ref('presence/$userId');
      await presenceRef.update({
        'isOnline': _isAppInForeground,
        'currentChatRoomId': _currentChatRoomId,
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      _logger.error('Failed to update presence: $e', tag: _tag);
    }
  }

  /// Clear presence data (call on logout).
  Future<void> clearPresence() async {
    final userId = _userId ?? _auth.currentUser?.uid;
    if (userId == null) {
      _logger.warning('Cannot clear presence - no userId available', tag: _tag);
      return;
    }

    try {
      final presenceRef = _database.ref('presence/$userId');
      
      // Cancel the onDisconnect handler
      await presenceRef.onDisconnect().cancel();
      
      // Set offline
      await presenceRef.set({
        'isOnline': false,
        'currentChatRoomId': null,
        'lastUpdated': ServerValue.timestamp,
      });

      _logger.debug('Presence cleared for user: $userId', tag: _tag);
    } catch (e) {
      _logger.error('Failed to clear presence: $e', tag: _tag);
    }
  }

  /// Dispose of the service and clean up subscriptions.
  Future<void> dispose() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _isInitialized = false;
    _currentChatRoomId = null;
    _userId = null;
    _logger.debug('UserPresenceService disposed', tag: _tag);
  }
}
