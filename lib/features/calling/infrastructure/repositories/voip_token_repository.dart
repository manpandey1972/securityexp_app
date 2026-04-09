import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import '../../services/callkit/callkit_service.dart';

/// Repository for managing VoIP push tokens.
///
/// VoIP tokens are used to wake the app for incoming calls when:
/// - The app is not running (killed)
/// - The phone is locked
/// - The app is in background
///
/// This repository:
/// - Stores the VoIP token in Firestore under the user's document
/// - Listens for token updates and syncs them
/// - Clears tokens on logout
class VoIPTokenRepository {
  final FirebaseFirestore _firestore;
  final CallKitService _callKitService;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'VoIPTokenRepository';

  StreamSubscription? _tokenSubscription;
  StreamSubscription? _invalidationSubscription;
  String? _currentUserId;
  String? _lastSavedToken;

  VoIPTokenRepository({
    FirebaseFirestore? firestore,
    CallKitService? callKitService,
  }) : _firestore = firestore ?? FirestoreInstance().db,
       _callKitService = callKitService ?? CallKitService();

  /// Initialize the repository for a specific user.
  ///
  /// This should be called after user login/onboarding when user document exists.
  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    if (!_callKitService.isAvailable) {
      _log.warning('CallKit not available on this platform', tag: _tag);
      return;
    }

    _log.debug('Initializing VoIP token repository', tag: _tag);

    // Cancel existing subscriptions to prevent duplicates
    _tokenSubscription?.cancel();
    _invalidationSubscription?.cancel();

    // Subscribe to token updates FIRST (before async fetch) to avoid
    // missing events on the broadcast stream during the await gap
    final capturedUserId = userId;
    _tokenSubscription = _callKitService.voipTokenUpdates.listen(
      (token) async {
        _log.debug('Received VoIP token update', tag: _tag);
        try {
          await _saveToken(capturedUserId, token);
        } catch (e, stackTrace) {
          _log.error(
            'Error saving token',
            tag: _tag,
            error: e,
            stackTrace: stackTrace,
          );
        }
      },
      onError: (e, stackTrace) {
        _log.error(
          'Token stream error',
          tag: _tag,
          error: e,
          stackTrace: stackTrace,
        );
      },
    );

    // Subscribe to token invalidation — clear from Firestore when Apple
    // invalidates the token so backend doesn't attempt stale VoIP pushes
    _invalidationSubscription = _callKitService.voipTokenInvalidated.listen(
      (_) async {
        _log.debug('VoIP token invalidated, clearing from Firestore', tag: _tag);
        try {
          await _clearTokenFromFirestore(capturedUserId);
        } catch (e, stackTrace) {
          _log.error(
            'Error clearing invalidated token',
            tag: _tag,
            error: e,
            stackTrace: stackTrace,
          );
        }
      },
    );

    // Now fetch current token as backup (in case event fired before subscription)
    final token = await _callKitService.getVoIPToken();
    if (token != null) {
      await _saveToken(userId, token);
    }

    _log.info('VoIP token repository initialized', tag: _tag);
  }

  /// Re-sync VoIP token with Firestore.
  ///
  /// Call this on app resume (foreground) to ensure Firestore stays up-to-date
  /// for users who stay logged in for extended periods without cold-starting.
  Future<void> refreshToken() async {
    final userId = _currentUserId;
    if (userId == null || !_callKitService.isAvailable) return;

    try {
      final token = await _callKitService.getVoIPToken();
      if (token != null) {
        if (token != _lastSavedToken) {
          _log.debug('VoIP token changed, updating Firestore', tag: _tag);
          await _saveToken(userId, token);
        }
      } else if (_lastSavedToken != null) {
        // Token was previously saved but is now null — clear from Firestore
        _log.debug('VoIP token gone, clearing from Firestore', tag: _tag);
        await _clearTokenFromFirestore(userId);
      }
    } catch (e, stackTrace) {
      _log.error(
        'Error refreshing VoIP token',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Save the VoIP token to Firestore
  Future<void> _saveToken(String userId, String token) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);

      await docRef.set({
        'voipToken': token,
        'voipTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': 'ios',
      }, SetOptions(merge: true));

      _lastSavedToken = token;
      _log.debug('VoIP token saved', tag: _tag);
    } catch (e, stackTrace) {
      _log.error(
        'Error saving VoIP token',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clear the VoIP token from Firestore (internal — called on invalidation)
  Future<void> _clearTokenFromFirestore(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'voipToken': FieldValue.delete(),
        'voipTokenUpdatedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      _lastSavedToken = null;
      _log.debug('VoIP token cleared from Firestore', tag: _tag);
    } catch (e, stackTrace) {
      _log.error(
        'Error clearing VoIP token from Firestore',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the VoIP token for a specific user (for sending push notifications)
  Future<String?> getTokenForUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['voipToken'] as String?;
    } catch (e) {
      _log.error('Error getting VoIP token', tag: _tag, error: e);
      return null;
    }
  }

  /// Clear the VoIP token from Firestore (call on logout)
  /// Pass userId explicitly to ensure cleanup works even if internal state is cleared
  Future<void> clearToken({String? userId}) async {
    final userIdToUse = userId ?? _currentUserId;
    if (userIdToUse == null) {
      _log.warning('No userId provided for clearToken', tag: _tag);
      return;
    }

    try {
      await _firestore.collection('users').doc(userIdToUse).set({
        'voipToken': FieldValue.delete(),
        'voipTokenUpdatedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      _log.debug('VoIP token cleared', tag: _tag);
    } catch (e) {
      // Permission denied is expected during account deletion (Auth user deleted first)
      // The token is already being cleaned up by the cloud function, so this is non-fatal
      if (e.toString().contains('permission-denied')) {
        _log.debug('VoIP token clear skipped (permission denied, likely during account deletion)', tag: _tag);
      } else {
        _log.error('Error clearing VoIP token', tag: _tag, error: e);
      }
    }
  }

  /// Dispose of resources
  void dispose() {
    _tokenSubscription?.cancel();
    _invalidationSubscription?.cancel();
    _currentUserId = null;
    _lastSavedToken = null;
  }
}
