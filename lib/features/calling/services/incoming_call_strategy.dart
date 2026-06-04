import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

import 'package:securityexperts_app/core/service_locator.dart';
import 'call_navigation_coordinator.dart';
import 'callkit/android_callkit_service.dart';
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
  final AndroidCallKitService _androidCallKitService =
      AndroidCallKitService();
  late final IncomingCallManager _incomingCallManager =
      sl<IncomingCallManager>();

  StreamSubscription? _callKitActionSubscription;
  StreamSubscription? _androidCallKitActionSubscription;
  bool _isInitialized = false;

  /// Track call IDs that are already being handled by CallKit
  /// Maps call ID -> timestamp when tracking started
  /// This prevents Firestore listener from showing duplicate Flutter dialog
  final Map<String, DateTime> _callsHandledByCallKit = {};

  /// Timestamp of last mute event processed — used to de-duplicate rapid
  /// CXSetMutedCallAction echoes that arrive within a short window.
  DateTime _lastMuteEventTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _lastMuteEventValue;

  /// Max age for tracked calls before automatic expiration (2 minutes)
  static const Duration _callTrackingExpiration = Duration(minutes: 2);

  /// Pending call data from VoIP push, waiting for CallKit answer/end action
  Map<String, dynamic>? _pendingCallData;

  /// Whether the platform supports CallKit (iOS only)
  /// Uses PlatformUtils for web-safe check
  bool get _isIOSPlatform => PlatformUtils.isIOS;

  /// Whether the platform is Android
  bool get _isAndroidPlatform => PlatformUtils.isAndroid;

  /// Whether CallKit can be used on this platform
  /// iOS uses native CallKit; Android uses flutter_callkit_incoming.
  bool get supportsCallKit => _isIOSPlatform || _isAndroidPlatform;

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
    } else if (_isAndroidPlatform) {
      // Subscribe to native CallKit events and process any already-accepted
      // calls (cold-start path) before we ever touch the Firestore listener.
      _setupAndroidCallKitListener();

      // Pre-track any call IDs the plugin currently considers "active" so the
      // Firestore listener (which fires as soon as Firebase Auth restores)
      // skips showing the in-app incoming-call banner. Without this, on
      // cold-start the Firestore listener races ahead of the auth-gated
      // synthesized `answerCall` and the user briefly sees the banner before
      // the call page appears.
      try {
        final preIds = await _androidCallKitService.peekActiveCallIds();
        for (final id in preIds) {
          _trackCallKitCall(id);
        }
        if (preIds.isNotEmpty) {
          sl<AppLogger>().debug(
            'Pre-tracked ${preIds.length} CallKit-handled call(s): $preIds',
            tag: 'IncomingCallStrategy',
          );
        }
      } catch (e) {
        sl<AppLogger>().warning(
          'Pre-track active CallKit calls failed: $e',
          tag: 'IncomingCallStrategy',
        );
      }

      await _androidCallKitService.initialize();
      sl<AppLogger>().debug(
        'Initialized for Android (flutter_callkit_incoming + Firestore)',
        tag: 'IncomingCallStrategy',
      );
    } else {
      sl<AppLogger>().debug(
        'Initialized for ${kIsWeb ? "Web" : "unknown"} (Firestore/FCM mode)',
        tag: 'IncomingCallStrategy',
      );
    }
  }

  /// Setup listener for Android CallKit (flutter_callkit_incoming) actions.
  /// Routes them through the same handlers as iOS CallKit so the rest of
  /// the system only sees one unified event stream.
  void _setupAndroidCallKitListener() {
    _androidCallKitActionSubscription?.cancel();
    _androidCallKitActionSubscription = _androidCallKitService.callActions.listen(
      (action) {
        sl<AppLogger>().debug(
          'Android CallKit action: ${action.action} for ${action.callUUID}',
          tag: 'IncomingCallStrategy',
        );

        // Mark this call as handled by CallKit to suppress duplicate Flutter
        // dialog from the Firestore listener.
        _trackCallKitCall(action.callUUID);
        final roomId = action.data?['room_id'] as String?;
        if (roomId != null && roomId != action.callUUID) {
          _trackCallKitCall(roomId);
        }

        switch (action.action) {
          case 'answerCall':
            _handleCallKitAnswer(action.callUUID, action.data);
            break;
          case 'endCall':
            _handleCallKitEnd(action.callUUID, action.data);
            break;
          case 'setMuted':
            _handleCallKitMute(action.data);
            break;
        }
      },
    );
  }

  /// Show the Android native incoming-call UI (full-screen ringing screen)
  /// for an incoming call. Called from the foreground FCM handler when a
  /// data message of type "incoming_call" arrives, and also pre-registers
  /// the call so the Firestore listener won't show a duplicate Flutter
  /// dialog.
  ///
  /// The background-isolate path lives in `firebase_messaging_service.dart`
  /// and calls `FlutterCallkitIncoming.showCallkitIncoming(...)` directly.
  Future<void> showAndroidCallKitIncomingCall({
    required String callId,
    required String callerId,
    required String callerName,
    required bool isVideo,
    String? roomId,
    String? callerAvatar,
  }) async {
    if (!_isAndroidPlatform) return;

    // Track ids so the Firestore listener path is suppressed.
    _trackCallKitCall(callId);
    if (roomId != null && roomId.isNotEmpty && roomId != callId) {
      _trackCallKitCall(roomId);
    }

    // Stash data needed at accept time (mirror of iOS _pendingCallData).
    _pendingCallData = {
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'room_id': roomId ?? callId,
      'is_video': isVideo,
    };

    await _androidCallKitService.showIncomingCall(
      callId: callId,
      callerName: callerName,
      isVideo: isVideo,
      callerAvatar: callerAvatar,
      extra: Map<String, dynamic>.from(_pendingCallData!),
    );
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
    // On Android, check if flutter_callkit_incoming is already showing the call
    // (FCM background handler may have already raised the native UI).
    if ((_isIOSPlatform || _isAndroidPlatform) &&
        _callsHandledByCallKit.containsKey(callId)) {
      sl<AppLogger>().debug(
        'Call $callId already handled by CallKit, skipping Flutter dialog',
        tag: 'IncomingCallStrategy',
      );
      return;
    }

    // On iOS, wait briefly for VoIP push to arrive before showing Flutter dialog
    // VoIP push can arrive up to ~400ms after Firestore notification
    // On Android, the FCM background handler may show CallKit UI in a separate
    // isolate; the corresponding `actionCallAccept`/`actionCallDecline` event
    // arrives in the main isolate after a short delay once the app is brought
    // up — wait briefly so we can detect it and suppress the Flutter dialog.
    if (_isIOSPlatform || _isAndroidPlatform) {
      sl<AppLogger>().debug(
        '${_isIOSPlatform ? "iOS" : "Android"}: waiting 500ms for native CallKit event...',
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
        '${_isIOSPlatform ? "iOS" : "Android"}: native CallKit event not received, showing Flutter dialog',
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

    // NOTE: deliberately do NOT clear `_callsHandledByCallKit` here.
    // The Firestore listener may still fire for this same call during the
    // brief window between status='active' and the doc being deleted. Leaving
    // the tracking in place ensures `handleIncomingCall` short-circuits and
    // we don't surface a second in-app accept dialog that would trigger a
    // duplicate acceptCall RPC. Tracking expires automatically after 2min
    // via the cleanup pass in `_trackCallKitCall`.
    _pendingCallData = null;
  }

  /// Handle end action from CallKit
  Future<void> _handleCallKitEnd(
    String callUUID,
    Map<String, dynamic>? data,
  ) async {
    sl<AppLogger>().debug('CallKit end for $callUUID', tag: 'IncomingCallStrategy');
    sl<AppLogger>().debug('End data: $data', tag: 'IncomingCallStrategy');

    // Check if there's an active connected call — end it via coordinator.
    //
    // On Android we apply a strict UUID-match guard. This is required because
    // our cold-start stale-purge path proactively calls
    // `FlutterCallkitIncoming.endCall(staleId)` and the plugin echoes back an
    // `actionCallEnded` event for that id. Without the guard, that echo would
    // tear down a live call the user just accepted.
    //
    // On iOS the `callUUID` is the CallKit UUID generated natively (does NOT
    // equal `activeController.callId`, which is the Firestore room id), and
    // the end event does not carry `room_id` in its data. Enforcing the
    // match here would cause iOS hang-ups (red End button) to be silently
    // ignored. iOS has no echo problem, so we trust any end event when an
    // active call exists.
    final coordinator = CallNavigationCoordinator();
    if (coordinator.activeController != null) {
      if (_isAndroidPlatform) {
        final active = coordinator.activeController!;
        final activeRoomId =
            active.session?.roomId ?? active.session?.callId ?? active.callId;
        final endRoomId =
            (data?['room_id'] as String?) ??
            (data?['roomName'] as String?) ??
            callUUID;
        final matches =
            (activeRoomId != null && activeRoomId == endRoomId) ||
            (active.callId != null && active.callId == callUUID);

        if (!matches) {
          sl<AppLogger>().debug(
            'Android CallKit end UUID $callUUID does not match active call '
            '(${active.callId}/$activeRoomId) — ignoring',
            tag: 'IncomingCallStrategy',
          );
          return;
        }
      }

      sl<AppLogger>().debug(
        'Active call found — ending via coordinator',
        tag: 'IncomingCallStrategy',
      );
      await coordinator.endCall();
      _pendingCallData = null;
      return;
    }

    // No active call controller — this is a pre-answer reject
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
      // No active call and no pending data — just dismiss any Flutter UI
      sl<AppLogger>().debug('No active call or pending data, just dismissing UI', tag: 'IncomingCallStrategy');
      _incomingCallManager.dismissIncomingCall();
    }
  }

  /// Handle mute action from CallKit native UI
  void _handleCallKitMute(Map<String, dynamic>? data) {
    final isMuted =
        data?['muted'] as bool? ?? data?['isMuted'] as bool? ?? false;
    sl<AppLogger>().debug('CallKit mute: $isMuted', tag: 'IncomingCallStrategy');

    // De-duplicate rapid mute events (CXSetMutedCallAction can echo multiple
    // times for a single mute press, especially from car displays)
    final now = DateTime.now();
    if (_lastMuteEventValue == isMuted &&
        now.difference(_lastMuteEventTime).inMilliseconds < 500) {
      sl<AppLogger>().debug(
        'Ignoring duplicate mute event (within 500ms)',
        tag: 'IncomingCallStrategy',
      );
      return;
    }
    _lastMuteEventTime = now;
    _lastMuteEventValue = isMuted;

    // Get the active call controller and set mute state explicitly
    final coordinator = CallNavigationCoordinator();
    final controller = coordinator.activeController;

    if (controller != null) {
      final currentMuted = controller.mediaManager?.isMuted.value ?? false;
      if (currentMuted != isMuted) {
        sl<AppLogger>().debug(
          'Syncing mute state: $currentMuted -> $isMuted',
          tag: 'IncomingCallStrategy',
        );
        // Use explicit setMicrophoneMuted instead of toggleMute to avoid
        // race conditions from toggle-based approach with remote commands.
        // syncToCallKit: false prevents a feedback loop — CallKit already
        // knows the mute state since the action originated from it.
        controller.setMicrophoneMuted(isMuted, syncToCallKit: false);
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
    if (_isIOSPlatform) {
      await _callKitService.endCall();
    } else if (_isAndroidPlatform) {
      await _androidCallKitService.endAllCalls();
    }
  }

  /// Dispose resources
  void dispose() {
    _callKitActionSubscription?.cancel();
    _androidCallKitActionSubscription?.cancel();
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
    if (_isAndroidPlatform && _androidCallKitService.hasActiveCall) {
      sl<AppLogger>().debug(
        'Ending active Android CallKit call on dispose',
        tag: 'IncomingCallStrategy',
      );
      _androidCallKitService.endAllCalls();
    }

    _isInitialized = false;
  }
}
