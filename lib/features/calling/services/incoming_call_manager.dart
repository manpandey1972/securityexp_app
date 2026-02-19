import 'package:flutter/material.dart';
import 'dart:async';
import 'package:greenhive_app/shared/services/ringtone_service.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/features/calling/pages/call_controller.dart';
import 'package:greenhive_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:greenhive_app/features/calling/services/interfaces/media_manager_factory.dart';
import 'package:greenhive_app/core/config/call_config.dart';
import 'package:greenhive_app/core/errors/call_error_handler.dart';
import 'package:greenhive_app/features/calling/services/call_logger.dart';
import 'package:greenhive_app/features/calling/services/analytics/call_analytics.dart';
import 'package:greenhive_app/features/calling/services/monitoring/network_quality_monitor.dart';
import 'package:greenhive_app/features/calling/services/callkit/callkit_service.dart';
import 'call_navigation_coordinator.dart';

/// Manages incoming call state and UI display
/// Extracted from call_page.dart _showIncomingCallOverlay logic
///
/// Access via service locator: `sl<IncomingCallManager>()`
class IncomingCallManager extends ChangeNotifier {
  IncomingCallManager() : _log = sl<AppLogger>();

  late final AppLogger _log;

  // Incoming call state
  bool _hasIncomingCall = false;
  Map<String, dynamic>? _incomingCallData;
  bool _isHandlingCall = false;
  Timer? _callTimeoutTimer;

  // Callbacks for UI integration
  VoidCallback? _onIncomingCall;
  VoidCallback? _onCallDismissed;
  Function(String)? _onCallAccepted;
  Function(String)? _onCallRejected;

  // ============== State Getters ==============
  bool get hasIncomingCall => _hasIncomingCall;
  Map<String, dynamic>? get incomingCallData => _incomingCallData;

  /// Derived from hasIncomingCall - less state = fewer bugs
  bool get isDialogShown => _hasIncomingCall;
  bool get isHandlingCall => _isHandlingCall;

  // ============== Callback Registration ==============
  void onIncomingCall(VoidCallback callback) {
    _onIncomingCall = callback;
  }

  void onCallDismissed(VoidCallback callback) {
    _onCallDismissed = callback;
  }

  void onCallAccepted(Function(String roomId) callback) {
    _onCallAccepted = callback;
  }

  void onCallRejected(Function(String roomId) callback) {
    _onCallRejected = callback;
  }

  // ============== Incoming Call Handling ==============

  /// Show incoming call overlay with ringtone
  void showIncomingCall(Map<String, dynamic> callData) {
    _log.info('=== SHOW INCOMING CALL START ===', tag: 'IncomingCallManager');
    _log.info(
      'Current state: hasIncomingCall=$_hasIncomingCall',
      tag: 'IncomingCallManager',
    );

    // Validate callData
    if (callData.isEmpty) {
      _log.error('Empty call data received', tag: 'IncomingCallManager');
      return;
    }

    final callerId = callData['caller_id'] as String? ?? '';
    final roomId = callData['room_id'] as String? ?? '';
    final isVideo = callData['is_video'] as bool? ?? false;

    _log.info(
      'showIncomingCall called',
      tag: 'IncomingCallManager',
      data: {
        'callData': callData,
        'caller_id': callerId,
        'room_id': roomId,
        'is_video': isVideo,
      },
    );

    if (callerId.isEmpty || roomId.isEmpty) {
      _log.error('Invalid call data: $callData', tag: 'IncomingCallManager');
      return;
    }

    _log.info(
      'Incoming call from: $callerId, room: $roomId',
      tag: 'IncomingCallManager',
    );

    // Prevent duplicate overlays
    if (_hasIncomingCall) {
      _log.warning(
        'Already showing incoming call, ignoring duplicate',
        tag: 'IncomingCallManager',
      );
      return;
    }

    _incomingCallData = callData;
    _hasIncomingCall = true;

    _log.info(
      'State updated: hasIncomingCall=$_hasIncomingCall',
      tag: 'IncomingCallManager',
    );

    // Start ringtone
    _startRingtone();

    // Start call timeout (30 seconds)
    _startCallTimeout(roomId);

    // Notify listeners
    _onIncomingCall?.call();
    notifyListeners();
    _log.info(
      '=== SHOW INCOMING CALL END - Listeners notified ===',
      tag: 'IncomingCallManager',
    );
  }

  /// Accept call from CallKit without showing Flutter UI
  ///
  /// This is called when the user accepts a call from the native CallKit UI.
  /// We skip showing the Flutter incoming call dialog and immediately connect
  /// to the call so audio works even before the app UI is visible.
  Future<void> acceptCallFromCallKit(Map<String, dynamic> callData) async {
    _log.info(
      'Accepting call from CallKit',
      tag: 'IncomingCallManager',
      data: {'callData': callData},
    );

    if (callData.isEmpty) {
      _log.error('Empty call data from CallKit', tag: 'IncomingCallManager');
      return;
    }

    final callerId = callData['caller_id'] as String? ?? '';
    final callerName = callData['caller_name'] as String? ?? 'Unknown Caller';
    final isVideo = callData['is_video'] as bool? ?? false;
    final roomId = callData['room_id'] as String? ?? '';

    if (callerId.isEmpty || roomId.isEmpty) {
      _log.error(
        'Invalid call data from CallKit: $callData',
        tag: 'IncomingCallManager',
      );
      return;
    }

    // Cancel timeout first to prevent race condition
    _cancelTimeout();

    // If there's an existing incoming call dialog, dismiss it
    if (_hasIncomingCall) {
      _log.info(
        'Dismissing existing Flutter dialog',
        tag: 'IncomingCallManager',
      );
      _stopRingtone();
      _hasIncomingCall = false;
      _incomingCallData = null;
    }

    _isHandlingCall = true;
    // Don't notify here - wait until work is done

    try {
      _log.info(
        'Setting up call from CallKit',
        tag: 'IncomingCallManager',
        data: {
          'callerName': callerName,
          'callerId': callerId,
          'roomId': roomId,
          'isVideo': isVideo,
        },
      );

      // Update CallNavigationCoordinator
      final coordinator = CallNavigationCoordinator();
      _log.info(
        'Got CallNavigationCoordinator instance',
        tag: 'IncomingCallManager',
      );

      // Pass roomId directly to initiateCall for incoming calls
      // This ensures hasActiveCall is true immediately when notifyListeners() fires
      coordinator.initiateCall(
        calleeId: callerId,
        calleeName: callerName,
        isVideo: isVideo,
        isCaller: false,
        roomId: roomId,
      );
      _log.info(
        'initiateCall done, isCallActive=${coordinator.isCallActive}',
        tag: 'IncomingCallManager',
      );

      // CRITICAL: Create CallController and connect immediately
      // This establishes the audio connection before the Flutter UI is visible
      // so the call works from the native CallKit screen
      _log.info(
        'Creating CallController for immediate connection',
        tag: 'IncomingCallManager',
      );

      final controller = CallController(
        isCaller: false,
        isVideo: isVideo,
        calleeId: callerId,
        callId: roomId,
        signaling: sl<SignalingService>(),
        mediaFactory: sl<MediaManagerFactory>(),
        logger: sl<CallLogger>(),
        config: sl<CallConfig>(),
        errorHandler: sl<CallErrorHandler>(),
        analytics: sl<CallAnalytics>(),
        networkMonitor: sl<NetworkQualityMonitor>(),
      );

      // Register with coordinator so VideoCallScreenV2 reuses this controller
      coordinator.startCall(controller, calleeName: callerName);

      // Start the connection process immediately - this enables audio
      _log.info(
        'Starting connection to enable audio',
        tag: 'IncomingCallManager',
      );
      controller.connect();

      // Notify callback to navigate to call page (if registered)
      _log.info(
        'Calling _onCallAccepted callback (is null: ${_onCallAccepted == null})',
        tag: 'IncomingCallManager',
      );
      _onCallAccepted?.call(roomId);
    } finally {
      _isHandlingCall = false;
      notifyListeners();
      _log.info('acceptCallFromCallKit complete', tag: 'IncomingCallManager');
    }
  }

  /// Reject call from CallKit without showing Flutter UI
  ///
  /// This is called when the user rejects a call from the native CallKit UI.
  Future<void> rejectCallFromCallKit(Map<String, dynamic> callData) async {
    _log.info(
      'Rejecting call from CallKit',
      tag: 'IncomingCallManager',
      data: {'callData': callData},
    );

    final roomId = callData['room_id'] as String? ?? '';

    // Cancel timeout first to prevent race condition
    _cancelTimeout();

    // If there's an existing incoming call dialog, dismiss it
    if (_hasIncomingCall) {
      _log.info(
        'Dismissing existing Flutter dialog',
        tag: 'IncomingCallManager',
      );
      _stopRingtone();
      _hasIncomingCall = false;
      _incomingCallData = null;
    }

    // Notify callback
    if (roomId.isNotEmpty) {
      _onCallRejected?.call(roomId);
    }

    _log.error('Call rejected from CallKit', tag: 'IncomingCallManager');
  }

  /// Accept incoming call
  Future<void> acceptCall() async {
    // Cancel timeout first to prevent race condition
    _cancelTimeout();

    if (_incomingCallData == null) {
      _log.error('No incoming call to accept', tag: 'IncomingCallManager');
      return;
    }

    _isHandlingCall = true;
    // Don't notify here - wait until work is done

    try {
      final callerId = _incomingCallData!['caller_id'] as String;
      final callerName =
          _incomingCallData!['caller_name'] as String? ?? 'Unknown Caller';
      final isVideo = _incomingCallData!['is_video'] as bool? ?? false;
      final roomId = _incomingCallData!['room_id'] as String;

      _log.info('Accepting call from $callerName', tag: 'IncomingCallManager');

      // Stop ringtone
      _stopRingtone();

      // Update CallNavigationCoordinator
      CallNavigationCoordinator().initiateCall(
        calleeId: callerId,
        calleeName: callerName,
        isVideo: isVideo,
        isCaller: false,
      );
      CallNavigationCoordinator().setRoomId(roomId);

      // Notify callback
      _onCallAccepted?.call(roomId);

      // Clear state
      _clearIncomingCall();
    } finally {
      _isHandlingCall = false;
      notifyListeners();
    }
  }

  /// Reject incoming call
  Future<void> rejectCall({Function(String roomId)? onRejectCallback}) async {
    // Cancel timeout first to prevent race condition
    _cancelTimeout();

    if (_incomingCallData == null) {
      _log.error('No incoming call to reject', tag: 'IncomingCallManager');
      return;
    }

    _isHandlingCall = true;
    // Don't notify here - wait until work is done

    try {
      final roomId = _incomingCallData!['room_id'] as String;

      _log.error(
        'Rejecting call from room: $roomId',
        tag: 'IncomingCallManager',
      );

      // Stop ringtone
      _stopRingtone();

      // Notify callback with room ID
      _onCallRejected?.call(roomId);
      if (onRejectCallback != null) {
        onRejectCallback(roomId);
      }

      // Clear state
      _clearIncomingCall();
    } finally {
      _isHandlingCall = false;
      notifyListeners();
    }
  }

  /// Dismiss incoming call (when caller cancels)
  void dismissIncomingCall() {
    _log.info('Incoming call dismissed', tag: 'IncomingCallManager');

    // Cancel timeout explicitly for clarity
    _cancelTimeout();
    _stopRingtone();

    // CRITICAL: End CallKit call on iOS when caller cancels
    // This dismisses the native incoming call screen
    _endCallKitCall();

    _clearIncomingCall();
    _onCallDismissed?.call();
    // notifyListeners already called by _clearIncomingCall
  }

  /// End CallKit call if active (iOS only)
  /// Called when caller cancels or call times out
  void _endCallKitCall() {
    try {
      final callKit = CallKitService();
      if (callKit.isAvailable && callKit.hasActiveCall) {
        _log.info(
          'Ending CallKit call - caller cancelled',
          tag: 'IncomingCallManager',
        );
        // Use reason 6 = CXCallEndedReason.remoteEnded (caller ended)
        callKit.endCall(reason: 6);
      }
    } catch (e) {
      _log.warning('Error ending CallKit call: $e', tag: 'IncomingCallManager');
    }
  }

  /// Force reset all state - called when app needs to ensure clean state
  /// Useful when a call ends and we want to ensure IncomingCallManager is ready for next call
  void forceReset() {
    // Guard: don't clobber an active call in progress
    if (_isHandlingCall) {
      _log.warning(
        'forceReset ignored while handling call',
        tag: 'IncomingCallManager',
      );
      return;
    }

    _log.debug('Force reset called', tag: 'IncomingCallManager');
    _log.debug(
      'Current state before reset: hasIncomingCall=$_hasIncomingCall, isHandlingCall=$_isHandlingCall',
      tag: 'IncomingCallManager',
    );

    _stopRingtone();
    _cancelTimeout();

    _hasIncomingCall = false;
    _incomingCallData = null;
    _isHandlingCall = false;

    _log.info(
      'Force reset complete - all state cleared',
      tag: 'IncomingCallManager',
    );

    // Delay notification to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // ============== Private Helper Methods ==============

  /// Start ringtone notification
  void _startRingtone() {
    try {
      RingtoneService().startRingtone();
      _log.info('Ringtone started', tag: 'IncomingCallManager');
    } catch (e) {
      _log.error('Failed to start ringtone: $e', tag: 'IncomingCallManager');
    }
  }

  /// Stop ringtone notification
  void _stopRingtone() {
    try {
      RingtoneService().stopRingtone();
      _log.info('Ringtone stopped', tag: 'IncomingCallManager');
    } catch (e) {
      _log.error('Failed to stop ringtone: $e', tag: 'IncomingCallManager');
    }
  }

  /// Start call timeout timer (calls expire after 30 seconds)
  void _startCallTimeout(String roomId) {
    _callTimeoutTimer?.cancel();
    _log.debug(
      'Starting 30 second timeout for room: $roomId',
      tag: 'IncomingCallManager',
    );
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      // Check if we still have an incoming call before timing out
      if (!_hasIncomingCall) {
        _log.debug(
          'Call already cleared, ignoring timeout',
          tag: 'IncomingCallManager',
        );
        return;
      }
      _log.debug(
        'Call timeout reached (30s) for room: $roomId',
        tag: 'IncomingCallManager',
      );
      dismissIncomingCall();
    });
  }

  /// Cancel call timeout timer
  void _cancelTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  /// Clear incoming call state
  void _clearIncomingCall() {
    _log.debug('=== CLEAR INCOMING CALL START ===', tag: 'IncomingCallManager');
    _log.debug(
      'Before clear: hasIncomingCall=$_hasIncomingCall',
      tag: 'IncomingCallManager',
    );

    _hasIncomingCall = false;
    _incomingCallData = null;
    _cancelTimeout();

    _log.debug(
      'After clear: hasIncomingCall=$_hasIncomingCall',
      tag: 'IncomingCallManager',
    );

    // Delay notification to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    _log.info(
      '=== CLEAR COMPLETE - Notification scheduled ===',
      tag: 'IncomingCallManager',
    );
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    super.dispose();
  }

  // ============== Debug Methods ==============

  @override
  String toString() =>
      '''
IncomingCallManager {
  hasIncomingCall: $_hasIncomingCall,
  isHandlingCall: $_isHandlingCall,
  callData: ${_incomingCallData != null ? 'present' : 'null'},
}''';
}
