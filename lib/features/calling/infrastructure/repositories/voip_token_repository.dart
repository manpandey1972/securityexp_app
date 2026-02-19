import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

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
  String? _currentUserId;

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

    // Get and save the current token (may be null if not yet received)
    final token = await _callKitService.getVoIPToken();
    if (token != null) {
      await _saveToken(userId, token);
    }

    // Cancel existing subscription to prevent duplicates
    _tokenSubscription?.cancel();

    // Listen for token updates (will fire when native sends token)
    // Using captured userId to ensure we save to correct user even if _currentUserId changes
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

    _log.info('VoIP token repository initialized', tag: _tag);
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
    _currentUserId = null;
  }
}
