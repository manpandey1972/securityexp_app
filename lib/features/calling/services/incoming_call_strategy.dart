import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

import 'package:greenhive_app/core/service_locator.dart';
import 'call_navigation_coordinator.dart';
import 'callkit/callkit_service.dart';
import 'incoming_call_manager.dart';
import 'interfaces/signaling_service.dart';
import 'platform_utils.dart';

/// Strategy for handling incoming calls based on platform.
///
/// **Call Flow:**
/// 1. Backend `createCall()` ALWAYS writes to Firestore `incoming_call` collection
/// 2. If app-level notification flag is ON, backend also sends VoIP push (iOS) or FCM (Android)
/// 3. Firestore listener is ALWAYS active as fallback for in-app scenarios
///
/// **Duplicate Prevention:**
/// - Track call IDs already shown via CallKit to prevent Firestore from showing Flutter dialog
/// - If CallKit already handling a call, Firestore event is ignored for that call
///
/// **Scenarios:**
/// - **iOS + VoIP push arrives first**: CallKit UI shown, Firestore event ignored
/// - **iOS + Firestore event only** (app-level notification OFF): Flutter dialog shown
/// - **iOS in foreground + VoIP push**: CallKit shown (native handles this)
/// - **Web/Android**: Always Firestore listener + Flutter dialog
class IncomingCallStrategy {
  static final IncomingCallStrategy _instance =
      IncomingCallStrategy._internal();
  factory IncomingCallStrategy() => _instance;
  IncomingCallStrategy._internal();

  final CallKitService _callKitService = CallKitService();
  late final IncomingCallManager _incomingCallManager =
      sl<IncomingCallManager>();

  StreamSubscription? _callKitActionSubscription;
  bool _isInitialized = false;

  /// Track call IDs that are already being handled by CallKit
  /// Maps call ID -> timestamp when tracking started
  /// This prevents Firestore listener from showing duplicate Flutter dialog
  final Map<String, DateTime> _callsHandledByCallKit = {};

  /// Max age for tracked calls before automatic expiration (2 minutes)
  static const Duration _callTrackingExpiration = Duration(minutes: 2);

  /// Pending call data from VoIP push, waiting for CallKit answer/end action
  Map<String, dynamic>? _pendingCallData;

  /// Whether the platform supports CallKit (iOS only)
  /// Uses PlatformUtils for web-safe check
  bool get _isIOSPlatform => PlatformUtils.isIOS;

  /// Whether CallKit can be used on this platform
  /// Note: This just checks platform capability, not notification permissions
  bool get supportsCallKit => _isIOSPlatform;

  /// Firestore listener should ALWAYS be active
  /// It serves as fallback when:
  /// - App-level notifications are OFF (no VoIP push sent)
  /// - System notifications are OFF (VoIP push blocked)
  /// - User is in the app and can receive calls regardless of notification settings
  bool get useFirestoreListener => true;

  /// Initialize the incoming call strategy
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // On iOS, setup CallKit listener for when VoIP pushes arrive
    if (_isIOSPlatform) {
      _setupCallKitListener();
      sl<AppLogger>().debug(
        'Initialized for iOS (CallKit + Firestore fallback)',
        tag: 'IncomingCallStrategy',
      );
    } else {
      sl<AppLogger>().debug(
        'Initialized for ${kIsWeb ? "Web" : "Android"} (Firestore/FCM mode)',
        tag: 'IncomingCallStrategy',
      );
    }
  }

  /// Setup listener for CallKit actions (answer, end, etc.)
  void _setupCallKitListener() {
    _callKitActionSubscription?.cancel();
    _callKitActionSubscription = _callKitService.callActions.listen((action) {
      sl<AppLogger>().debug('CallKit action: ${action.action}', tag: 'IncomingCallStrategy');

      switch (action.action) {
        case 'answerCall':
          _handleCallKitAnswer(action.callUUID, action.data);
          break;
        case 'endCall':
          _handleCallKitEnd(action.callUUID, action.data);
          break;
        case 'startCall':
          // Outgoing call started from CallKit
          break;
        case 'setMuted':
          // Handle mute from CallKit UI - toggle mute on active call
          _handleCallKitMute(action.data);
          break;
      }
    });
  }

  /// Handle incoming call from Firestore listener
  ///
  /// This is called when Firestore detects an incoming call document.
  /// On iOS, we check if CallKit is already handling this call to prevent duplicates.
  Future<void> handleIncomingCall(Map<String, dynamic> callData) async {
    final callId = _extractCallKey(callData) ?? '';

    sl<AppLogger>().debug(
      'handleIncomingCall: callId=$callId, isIOS=$_isIOSPlatform',
      tag: 'IncomingCallStrategy',
    );

    // Clean up expired tracked calls first
    _cleanupExpiredTrackedCalls();

    // Check if call is already ended or rejected (stale Firestore data)
    final status = callData['status'] as String?;
    if (status == 'ended' ||
        status == 'rejected' ||
        status == 'cancelled' ||
        status == 'missed') {
      sl<AppLogger>().debug(
        'Call $callId already $status, ignoring',
        tag: 'IncomingCallStrategy',
      );
      return;
    }

    // On iOS, check if this call is already being handled by CallKit (via VoIP push)
    if (_isIOSPlatform && _callsHandledByCallKit.containsKey(callId)) {
      sl<AppLogger>().debug(
        'Call $callId already handled by CallKit, skipping Flutter dialog',
        tag: 'IncomingCallStrategy',
      );
      return;
    }

    // On iOS, wait briefly for VoIP push to arrive before showing Flutter dialog
    // VoIP push can arrive up to ~400ms after Firestore notification
    if (_isIOSPlatform) {
      sl<AppLogger>().debug(
        'iOS: waiting 500ms for VoIP push...',
        tag: 'IncomingCallStrategy',
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Re-check if CallKit handled it during the delay
      if (_callsHandledByCallKit.containsKey(callId)) {
        sl<AppLogger>().debug(
          'Call $callId now handled by CallKit after delay, skipping Flutter dialog',
          tag: 'IncomingCallStrategy',
        );
        return;
      }
      sl<AppLogger>().debug(
        'iOS: VoIP push not received, showing Flutter dialog',
        tag: 'IncomingCallStrategy',
      );
    }

    // Check if IncomingCallManager is already showing a call
    if (_incomingCallManager.hasIncomingCall) {
      sl<AppLogger>().debug(
        'Already showing incoming call, skipping',
        tag: 'IncomingCallStrategy',
      );
      return;
    }

    // Debug assertion to catch race conditions
    assert(
      !_incomingCallManager.hasIncomingCall,
      'Incoming call dialog already shown!',
    );

    // Show Flutter incoming call dialog
    sl<AppLogger>().debug(
      'Showing Flutter dialog for call $callId',
      tag: 'IncomingCallStrategy',
    );
    _incomingCallManager.showIncomingCall(callData);
  }

  /// Extract call ID from various possible keys in call data
  String? _extractCallKey(Map<String, dynamic> data) {
    return data['call_id'] as String? ??
        data['room_id'] as String? ??
        data['roomName'] as String? ??
        data['callId'] as String?;
  }

  /// Clean up tracked calls that have expired (older than 2 minutes)
  void _cleanupExpiredTrackedCalls() {
    final now = DateTime.now();
    _callsHandledByCallKit.removeWhere(
      (_, time) => now.difference(time) > _callTrackingExpiration,
    );
  }

  /// Track a call ID as being handled by CallKit
  void _trackCallKitCall(String? callId) {
    if (callId != null && callId.isNotEmpty) {
      _callsHandledByCallKit[callId] = DateTime.now();
    }
  }

  /// Handle incoming call from VoIP push (iOS only)
  ///
  /// This is called by PushKitManager when a VoIP push arrives.
  /// CallKit UI is already shown by native code, this bridges to Flutter.
  Future<void> handleVoIPPushCall({
    required String callId,
    required String callerId,
    required String callerName,
    required bool hasVideo,
    String? roomName,
  }) async {
    if (!_isIOSPlatform) {
      sl<AppLogger>().warning(
        'VoIP push received on non-iOS platform',
        tag: 'IncomingCallStrategy',
      );
      return;
    }

    sl<AppLogger>().debug(
      'VoIP push call: $callerName ($callerId), callId=$callId, roomName=$roomName',
      tag: 'IncomingCallStrategy',
    );

    // Guard against overwriting pending call data from a previous VoIP push
    if (_pendingCallData != null) {
      sl<AppLogger>().debug(
        'Pending call already exists, ignoring new VoIP push',
        tag: 'IncomingCallStrategy',
      );
      return;
    }

    // Mark this call as handled by CallKit to prevent Firestore from showing Flutter dialog
    // Add both callId and roomName since either might be used
    _trackCallKitCall(callId);
    if (roomName != null && roomName.isNotEmpty && roomName != callId) {
      _trackCallKitCall(roomName);
    }

    sl<AppLogger>().debug(
      'Tracking call IDs: ${_callsHandledByCallKit.keys.toList()}',
      tag: 'IncomingCallStrategy',
    );

    // If Flutter dialog is already showing for this call, dismiss it
    // (VoIP push arrived after Firestore event - rare but possible)
    if (_incomingCallManager.hasIncomingCall) {
      sl<AppLogger>().debug(
        'Dismissing Flutter dialog, CallKit taking over',
        tag: 'IncomingCallStrategy',
      );
      _incomingCallManager.dismissIncomingCall();
    }

    // Store call data for when user answers from CallKit
    _pendingCallData = {
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'room_id': roomName ?? callId,
      'is_video': hasVideo,
      'call_uuid': _callKitService.activeCallUUID,
    };

    // CallKit UI is already showing (handled by native PushKitManager)
    // We just need to be ready to handle the answer action
  }

  /// Handle answer action from CallKit
  void _handleCallKitAnswer(String callUUID, Map<String, dynamic>? data) {
    sl<AppLogger>().debug('CallKit answer for $callUUID', tag: 'IncomingCallStrategy');
    sl<AppLogger>().debug('Answer data from native: $data', tag: 'IncomingCallStrategy');
    sl<AppLogger>().debug(
      'Pending call data: $_pendingCallData',
      tag: 'IncomingCallStrategy',
    );

    final callData = _pendingCallData ?? data ?? {};
    sl<AppLogger>().debug('Merged call data: $callData', tag: 'IncomingCallStrategy');

    if (callData.isEmpty) {
      sl<AppLogger>().warning('No call data for answered call', tag: 'IncomingCallStrategy');
      return;
    }

    // Accept call directly from CallKit without showing Flutter UI
    sl<AppLogger>().debug('Calling acceptCallFromCallKit...', tag: 'IncomingCallStrategy');
    _incomingCallManager.acceptCallFromCallKit(callData);

    _cleanupCallKitTracking(callData['call_id'] as String?);
    _cleanupCallKitTracking(callData['room_id'] as String?);
    _pendingCallData = null;
  }

  /// Handle end action from CallKit
  Future<void> _handleCallKitEnd(
    String callUUID,
    Map<String, dynamic>? data,
  ) async {
    sl<AppLogger>().debug('CallKit end for $callUUID', tag: 'IncomingCallStrategy');
    sl<AppLogger>().debug('End data: $data', tag: 'IncomingCallStrategy');

    // Get call data from pending data or from the action data
    final callData = _pendingCallData ?? data ?? {};

    if (callData.isNotEmpty) {
      final roomId =
          callData['room_id'] as String? ??
          callData['roomName'] as String? ??
          callData['callId'] as String? ??
          '';

sl<AppLogger>().debug(
          'Rejecting call with roomId: $roomId',
          tag: 'IncomingCallStrategy',
      );

      // Dismiss Flutter UI if showing
      _incomingCallManager.rejectCallFromCallKit(callData);

      // Signal backend to reject the call
      if (roomId.isNotEmpty) {
        sl<AppLogger>().debug(
          'Calling signaling.rejectCall for: $roomId',
          tag: 'IncomingCallStrategy',
        );
        try {
          final signaling = GetIt.instance<SignalingService>();
          await signaling.rejectCall(roomId);
        } catch (e) {
          sl<AppLogger>().error('Failed to reject call', tag: 'IncomingCallStrategy', error: e);
        }
      }

      _cleanupCallKitTracking(callData['call_id'] as String?);
      _cleanupCallKitTracking(callData['room_id'] as String?);
      _cleanupCallKitTracking(callData['roomName'] as String?);
      _pendingCallData = null;
    } else {
      // Active call being ended - just dismiss any Flutter UI
      sl<AppLogger>().debug('No call data, just dismissing UI', tag: 'IncomingCallStrategy');
      _incomingCallManager.dismissIncomingCall();
    }
  }

  /// Handle mute action from CallKit native UI
  void _handleCallKitMute(Map<String, dynamic>? data) {
    final isMuted =
        data?['muted'] as bool? ?? data?['isMuted'] as bool? ?? false;
    sl<AppLogger>().debug('CallKit mute: $isMuted', tag: 'IncomingCallStrategy');

    // Get the active call controller and toggle mute
    final coordinator = CallNavigationCoordinator();
    final controller = coordinator.activeController;

    if (controller != null) {
      // Only toggle if the state differs from current
      final currentMuted = controller.mediaManager?.isMuted.value ?? false;
      if (currentMuted != isMuted) {
        sl<AppLogger>().debug(
          'Syncing mute state: $currentMuted -> $isMuted',
          tag: 'IncomingCallStrategy',
        );
        controller.toggleMute();
      } else {
        sl<AppLogger>().debug('Mute already in sync: $isMuted', tag: 'IncomingCallStrategy');
      }
    } else {
      sl<AppLogger>().warning('No active controller for mute', tag: 'IncomingCallStrategy');
    }
  }

  /// Remove call from CallKit tracking set
  void _cleanupCallKitTracking(String? callId) {
    if (callId != null) {
      _callsHandledByCallKit.remove(callId);
    }
  }

  /// Report an outgoing call to CallKit (iOS) or just proceed (other platforms)
  Future<String?> reportOutgoingCall({
    required String calleeName,
    required String calleeId,
    required bool hasVideo,
  }) async {
    if (!_isIOSPlatform) return null;

    return await _callKitService.reportOutgoingCall(
      calleeName: calleeName,
      calleeId: calleeId,
      hasVideo: hasVideo,
    );
  }

  /// Report that outgoing call connected
  Future<void> reportOutgoingCallConnected() async {
    if (!_isIOSPlatform) return;
    await _callKitService.reportOutgoingCallConnected();
  }

  /// End call on CallKit
  Future<void> endCall() async {
    if (!_isIOSPlatform) return;
    await _callKitService.endCall();
  }

  /// Dispose resources
  void dispose() {
    _callKitActionSubscription?.cancel();
    _callsHandledByCallKit.clear();
    _pendingCallData = null;

    // End any active CallKit calls to prevent orphaned UI
    if (_isIOSPlatform && _callKitService.hasActiveCall) {
      sl<AppLogger>().debug(
        'Ending active CallKit call on dispose',
        tag: 'IncomingCallStrategy',
      );
      _callKitService.endCall();
    }

    _isInitialized = false;
  }
}
