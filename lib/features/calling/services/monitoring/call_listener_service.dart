import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/calling/services/incoming_call_manager.dart';
import 'package:greenhive_app/features/calling/services/incoming_call_strategy.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';

class CallListenerService {
  static final CallListenerService _instance = CallListenerService._internal();
  factory CallListenerService() => _instance;
  CallListenerService._internal();

  StreamSubscription? _authSub;
  StreamSubscription? _callSub;
  StreamSubscription? _callStatusSub; // Listen to call status for cancellation
  final SignalingService _signaling = sl<SignalingService>();
  late final IncomingCallManager _incomingManager = sl<IncomingCallManager>();
  final IncomingCallStrategy _callStrategy = IncomingCallStrategy();

  // Track processed call IDs to prevent duplicates
  final Set<String> _processedCallIds = {};

  // Guard to prevent multiple initializations
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      sl<AppLogger>().warning('Already initialized, skipping', tag: 'CallListenerService');
      return;
    }
    _isInitialized = true;
    sl<AppLogger>().debug('Initializing...', tag: 'CallListenerService');

    // Initialize the call strategy (handles CallKit listener on iOS)
    await _callStrategy.initialize();

    // Firestore listener is ALWAYS active as fallback for:
    // - Users with app-level notifications OFF (no VoIP push sent)
    // - Users with system notifications OFF (VoIP push blocked)
    // - Users who are in the app and can receive calls regardless of notification settings
    // The IncomingCallStrategy handles duplicate prevention if CallKit already showed the call
    sl<AppLogger>().debug(
      'Setting up Firestore listener (always active as fallback)',
      tag: 'CallListenerService',
    );
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      sl<AppLogger>().debug(
        'Auth state changed: user=${user?.uid}',
        tag: 'CallListenerService',
      );
      _cleanupCallListener();
      if (user != null) {
        _startListening(user.uid);
        // Note: VoIP token syncing is now handled by AuthProvider
      }
    });
  }

  void _startListening(String userId) {
    // Cancel any existing subscription to prevent duplicates
    _callSub?.cancel();
    _callSub = _signaling.listenForIncomingCalls(userId).listen((
      sessions,
    ) async {
      sl<AppLogger>().debug(
        'Received ${sessions.length} incoming call(s)',
        tag: 'CallListenerService',
      );
      if (sessions.isEmpty) return;

      // For now, just handle the first one
      final session = sessions.first;
      sl<AppLogger>().debug('Processing call: ${session.callId}', tag: 'CallListenerService');
      sl<AppLogger>().debug('   isVideo: ${session.isVideo}, caller: ${session.callerId}', tag: 'CallListenerService');

      // Skip if we already processed this call (atomic check-and-add to prevent race)
      if (!_processedCallIds.add(session.callId)) {
        sl<AppLogger>().debug(
          'Already processed call: ${session.callId}',
          tag: 'CallListenerService',
        );
        return;
      }

      // Check if we are already handling this call or another call
      if (_incomingManager.hasIncomingCall) {
        sl<AppLogger>().debug('Already showing incoming call', tag: 'CallListenerService');
        return;
      }

      // Clean up old call IDs (keep only last 10 to prevent memory leak)
      if (_processedCallIds.length > 10) {
        final oldest = _processedCallIds.first;
        _processedCallIds.remove(oldest);
      }

      // Fetch caller's display name from Firestore
      String callerName = 'Unknown Caller';
      try {
        final doc = await FirestoreInstance().db
            .collection('users')
            .doc(session.callerId)
            .get();
        if (doc.exists) {
          // Convert to Map explicitly for web compatibility
          final rawData = doc.data();
          if (rawData != null) {
            final data = Map<String, dynamic>.from(rawData);
            callerName =
                data['name'] ?? data['displayName'] ?? 'Unknown Caller';
          }
        }
      } catch (e) {
        sl<AppLogger>().warning('Failed to fetch caller name: $e', tag: 'CallListenerService');
      }

      // Create data map matching what IncomingCallManager expects
      final callData = {
        'caller_id': session.callerId,
        'room_id': session.roomId,
        'call_id': session.callId, // Add call_id for CallKit tracking
        'caller_name': callerName,
        'is_video': session.isVideo,
      };

      // Use IncomingCallStrategy to handle the call
      // This will skip showing Flutter dialog if CallKit already handling it
      await _callStrategy.handleIncomingCall(callData);

      // Listen for call cancellation by monitoring the call room status
      _setupCallStatusListener(session.roomId);

      // NOTE: Don't delete the incoming_calls document here!
      // It should be cleaned up by Cloud Functions when the call ends
    });
  }

  /// Setup listener for call status changes (to detect cancellation)
  void _setupCallStatusListener(String roomId) {
    // Cancel any existing listener
    _callStatusSub?.cancel();

    sl<AppLogger>().debug(
      'Listening to call status for room: $roomId',
      tag: 'CallListenerService',
    );

    _callStatusSub = FirestoreInstance().db
        .collection('livekit_rooms')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
          // Convert snapshot data to proper Dart Map for web compatibility
          if (!snapshot.exists) return null;
          final rawData = snapshot.data();
          if (rawData == null) return null;
          // Use json encode/decode to ensure proper Dart Map on web
          return {'exists': true, 'data': rawData, 'snapshot': snapshot};
        })
        .listen(
          (result) {
            if (result == null) {
              sl<AppLogger>().debug(
                'Call room deleted - dismissing incoming call',
                tag: 'CallListenerService',
              );
              _incomingManager.dismissIncomingCall();
              _callStatusSub?.cancel();
              _callStatusSub = null;
              return;
            }

            // Access data from the wrapped result
            final rawData = result['data'];
            if (rawData == null) return;

            // Convert to proper Dart Map - handle web JS interop
            String? status;
            try {
              if (rawData is Map) {
                status = rawData['status']?.toString();
              } else {
                // On web, try accessing as dynamic
                final dynamic dynData = rawData;
                status = (dynData['status'] as dynamic)?.toString();
              }
            } catch (e) {
              sl<AppLogger>().warning('Error reading status: $e', tag: 'CallListenerService');
              return;
            }

            sl<AppLogger>().debug('Call status changed: $status', tag: 'CallListenerService');

            // Auto-dismiss dialog if call was cancelled, missed, or rejected
            if (status == 'cancelled' ||
                status == 'missed' ||
                status == 'rejected' ||
                status == 'ended') {
              sl<AppLogger>().debug(
                'Call $status - dismissing incoming call dialog',
                tag: 'CallListenerService',
              );
              _incomingManager.dismissIncomingCall();
              _callStatusSub?.cancel();
              _callStatusSub = null;
            }
          },
          onError: (e) {
            sl<AppLogger>().warning(
              'Error listening to call status: $e',
              tag: 'CallListenerService',
            );
          },
        );
  }

  void _cleanupCallListener() {
    _callSub?.cancel();
    _callSub = null;
    _callStatusSub?.cancel();
    _callStatusSub = null;
    // Note: We do NOT clear _processedCallIds here because auth state can
    // change multiple times (token refresh) and we need to remember which
    // calls we already processed to prevent duplicates.
  }

  void dispose() {
    _authSub?.cancel();
    _cleanupCallListener();
  }
}
