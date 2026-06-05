import 'dart:async';

import '../call_navigation_coordinator.dart';
import '../callkit/callkit_service.dart';
import '../interfaces/signaling_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import 'incoming_call_path.dart';

/// iOS implementation: native CallKit (via `flutter_callkit_incoming`'s iOS
/// surface) handles incoming and outgoing call UI. The Firestore listener
/// is a fallback for the case where app-level notifications are off and no
/// VoIP push is delivered.
class IosIncomingCallPath extends IncomingCallPath
    with CallKitTrackingMixin, CallKitMuteDedupMixin {
  IosIncomingCallPath();

  final CallKitService _callKitService = CallKitService();
  StreamSubscription? _eventSub;

  /// Stashed at VoIP push time so the subsequent `answerCall` /  `endCall`
  /// event from CallKit knows the Firestore room id, caller name, etc.
  Map<String, dynamic>? _pendingCallData;

  @override
  String get tag => 'IosIncomingCallPath';

  /// Exposed for the facade's outgoing-call delegation (used by
  /// `CallNavigationCoordinator._reportOutgoingCallToCallKit` through the
  /// global `CallKitService` singleton, not this field — kept for parity).
  CallKitService get callKitService => _callKitService;

  @override
  Future<void> initialize() async {
    _eventSub?.cancel();
    _eventSub = _callKitService.callActions.listen((action) {
      log.debug('CallKit action: ${action.action}', tag: tag);
      switch (action.action) {
        case 'answerCall':
          _handleAnswer(action.callUUID, action.data);
          break;
        case 'endCall':
          _handleEnd(action.callUUID, action.data);
          break;
        case 'startCall':
          // Outgoing call started from CallKit — nothing to do here.
          break;
        case 'setMuted':
          _handleMute(action.data);
          break;
      }
    });
    log.debug(
      'Initialized for iOS (CallKit + Firestore fallback)',
      tag: tag,
    );
  }

  @override
  Future<void> handleIncomingCall(Map<String, dynamic> callData) async {
    final callId = extractCallKey(callData) ?? '';
    log.debug('handleIncomingCall: callId=$callId', tag: tag);

    final status = callData['status'] as String?;
    if (isStaleCallStatus(status)) {
      log.debug('Call $callId already $status, ignoring', tag: tag);
      return;
    }

    if (callId.isNotEmpty && isHandledByCallKit(callId)) {
      log.debug(
        'Call $callId already handled by CallKit, skipping Flutter dialog',
        tag: tag,
      );
      return;
    }

    // Wait briefly for the VoIP push to arrive before showing the Flutter
    // dialog. The Firestore path can outrun the VoIP push by ~400ms; without
    // this delay we'd briefly show both UIs.
    log.debug('iOS: waiting 500ms for VoIP push...', tag: tag);
    await Future.delayed(const Duration(milliseconds: 500));
    if (callId.isNotEmpty && isHandledByCallKit(callId)) {
      log.debug(
        'Call $callId now handled by CallKit after delay, skipping',
        tag: tag,
      );
      return;
    }
    log.debug(
      'iOS: VoIP push did not arrive, showing Flutter dialog',
      tag: tag,
    );

    if (incomingCallManager.hasIncomingCall) {
      log.debug('Already showing incoming call, skipping', tag: tag);
      return;
    }

    incomingCallManager.showIncomingCall(callData);
  }

  /// Bridge a VoIP push (CallKit UI already shown by native PushKitManager)
  /// to the Dart side: stash data so the next `answerCall` event has all
  /// the routing info, and dismiss any in-app dialog that beat us.
  Future<void> handleVoIPPushCall({
    required String callId,
    required String callerId,
    required String callerName,
    required bool hasVideo,
    String? roomName,
  }) async {
    log.debug(
      'VoIP push: $callerName ($callerId), callId=$callId, roomName=$roomName',
      tag: tag,
    );

    if (_pendingCallData != null) {
      log.debug(
        'Pending call already exists, ignoring new VoIP push',
        tag: tag,
      );
      return;
    }

    trackCallKitCall(callId);
    if (roomName != null && roomName.isNotEmpty && roomName != callId) {
      trackCallKitCall(roomName);
    }
    log.debug('Tracking call IDs: ${trackedIds.toList()}', tag: tag);

    if (incomingCallManager.hasIncomingCall) {
      log.debug('Dismissing Flutter dialog, CallKit taking over', tag: tag);
      incomingCallManager.dismissIncomingCall();
    }

    _pendingCallData = {
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'room_id': roomName ?? callId,
      'is_video': hasVideo,
      'call_uuid': _callKitService.activeCallUUID,
    };
  }

  void _handleAnswer(String callUUID, Map<String, dynamic>? data) {
    log.debug('CallKit answer for $callUUID', tag: tag);
    final callData = _pendingCallData ?? data ?? const <String, dynamic>{};
    dispatchCallKitAnswer(
      log: log,
      tag: tag,
      manager: incomingCallManager,
      callData: callData,
    );
    // Deliberately do NOT clear CallKit tracking here. The Firestore
    // listener may still fire for this same call during the brief window
    // between status=active and the doc being deleted. Leaving the entry
    // in place ensures handleIncomingCall short-circuits and we don't
    // surface a duplicate in-app accept dialog. Tracking expires after 2m.
    _pendingCallData = null;
  }

  Future<void> _handleEnd(String callUUID, Map<String, dynamic>? data) async {
    log.debug('CallKit end for $callUUID (data=$data)', tag: tag);

    // iOS: trust any end event when an active call exists. The CallKit
    // UUID is generated natively and does NOT equal `activeController.callId`
    // (which is the Firestore room id), so enforcing an id match here would
    // silently ignore real hang-ups. iOS has no echo problem (unlike the
    // Android plugin's stale-purge echo, which the Android path guards).
    final coordinator = CallNavigationCoordinator();
    if (coordinator.activeController != null) {
      log.debug('Active call found — ending via coordinator', tag: tag);
      await coordinator.endCall();
      _pendingCallData = null;
      return;
    }

    // No active controller — pre-answer reject.
    final callData = _pendingCallData ?? data ?? const <String, dynamic>{};
    if (callData.isNotEmpty) {
      final roomId = callData['room_id'] as String? ??
          callData['roomName'] as String? ??
          callData['callId'] as String? ??
          '';
      log.debug('Rejecting call roomId=$roomId', tag: tag);
      incomingCallManager.rejectCallFromCallKit(callData);
      if (roomId.isNotEmpty) {
        try {
          await sl<SignalingService>().rejectCall(roomId);
        } catch (e) {
          log.error('Failed to reject call', tag: tag, error: e);
        }
      }
      untrack(callData['call_id'] as String?);
      untrack(callData['room_id'] as String?);
      untrack(callData['roomName'] as String?);
      _pendingCallData = null;
    } else {
      log.debug(
        'No active call or pending data, dismissing UI',
        tag: tag,
      );
      incomingCallManager.dismissIncomingCall();
    }
  }

  void _handleMute(Map<String, dynamic>? data) {
    final isMuted =
        data?['muted'] as bool? ?? data?['isMuted'] as bool? ?? false;
    log.debug('CallKit mute: $isMuted', tag: tag);
    if (isDuplicateMuteEvent(isMuted)) {
      log.debug('Ignoring duplicate mute event (within 500ms)', tag: tag);
      return;
    }
    dispatchCallKitMute(log: log, tag: tag, isMuted: isMuted);
  }

  Future<String?> reportOutgoingCall({
    required String calleeName,
    required String calleeId,
    required bool hasVideo,
  }) {
    return _callKitService.reportOutgoingCall(
      calleeName: calleeName,
      calleeId: calleeId,
      hasVideo: hasVideo,
    );
  }

  Future<void> reportOutgoingCallConnected() =>
      _callKitService.reportOutgoingCallConnected();

  Future<void> endActiveCall() => _callKitService.endCall();

  void dispose() {
    _eventSub?.cancel();
    clearTracking();
    _pendingCallData = null;
    if (_callKitService.hasActiveCall) {
      log.debug('Ending active CallKit call on dispose', tag: tag);
      _callKitService.endCall();
    }
  }
}
