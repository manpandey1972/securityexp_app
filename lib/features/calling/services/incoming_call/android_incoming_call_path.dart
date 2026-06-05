import 'dart:async';

import '../call_navigation_coordinator.dart';
import '../callkit/android_callkit_service.dart';

import 'incoming_call_path.dart';

/// Android implementation: native incoming-call UI via
/// `flutter_callkit_incoming`, surfaced by [AndroidCallKitService]. The
/// Firestore listener is a fallback for the case where the FCM data
/// message is delayed or suppressed.
///
/// Key Android-specific quirks handled here:
///   * **Cold-start pre-tracking** — when the app launches via a CallKit
///     accept on a killed process, the plugin's in-memory ACTIVE_CALLS
///     map already contains the call id; we pre-track those ids so the
///     Firestore listener (which fires the moment Firebase Auth restores)
///     doesn't briefly show a duplicate in-app banner.
///   * **Strict UUID-match guard on end** — our cold-start stale-purge
///     path calls `FlutterCallkitIncoming.endCall(staleId)`, which makes
///     the plugin echo `actionCallEnded` back. Without the guard that
///     echo would tear down a live call the user just accepted.
class AndroidIncomingCallPath extends IncomingCallPath
    with CallKitTrackingMixin, CallKitMuteDedupMixin {
  AndroidIncomingCallPath();

  final AndroidCallKitService _androidCallKitService = AndroidCallKitService();
  StreamSubscription? _eventSub;

  @override
  String get tag => 'AndroidIncomingCallPath';

  AndroidCallKitService get androidCallKitService => _androidCallKitService;

  @override
  Future<void> initialize() async {
    _eventSub?.cancel();
    _eventSub = _androidCallKitService.callActions.listen((action) {
      log.debug(
        'Android CallKit action: ${action.action} for ${action.callUUID}',
        tag: tag,
      );

      // Mark this call as handled by CallKit so a Firestore event arriving
      // moments later doesn't surface the in-app banner on top.
      trackCallKitCall(action.callUUID);
      final roomId = action.data?['room_id'] as String?;
      if (roomId != null && roomId != action.callUUID) {
        trackCallKitCall(roomId);
      }

      switch (action.action) {
        case 'answerCall':
          _handleAnswer(action.callUUID, action.data);
          break;
        case 'endCall':
          _handleEnd(action.callUUID, action.data);
          break;
        case 'setMuted':
          _handleMute(action.data);
          break;
      }
    });

    // Pre-track any call ids the plugin currently considers "active" so the
    // Firestore listener (which fires as soon as Firebase Auth restores)
    // skips showing the in-app incoming-call banner. Without this, on cold
    // start the Firestore listener races ahead of the auth-gated synthesized
    // `answerCall` and the user briefly sees the banner before the call
    // page appears.
    try {
      final preIds = await _androidCallKitService.peekActiveCallIds();
      for (final id in preIds) {
        trackCallKitCall(id);
      }
      if (preIds.isNotEmpty) {
        log.debug(
          'Pre-tracked ${preIds.length} CallKit-handled call(s): $preIds',
          tag: tag,
        );
      }
    } catch (e) {
      log.warning('Pre-track active CallKit calls failed: $e', tag: tag);
    }

    await _androidCallKitService.initialize();
    log.debug(
      'Initialized for Android (flutter_callkit_incoming + Firestore)',
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

    // The FCM background handler may show CallKit UI in a separate
    // isolate; the corresponding `actionCallAccept` / `actionCallDecline`
    // event arrives in the main isolate after a short delay once the app
    // is brought up. Wait briefly so we can detect it and suppress the
    // Flutter dialog.
    log.debug('Android: waiting 500ms for native CallKit event...', tag: tag);
    await Future.delayed(const Duration(milliseconds: 500));
    if (callId.isNotEmpty && isHandledByCallKit(callId)) {
      log.debug(
        'Call $callId now handled by CallKit after delay, skipping',
        tag: tag,
      );
      return;
    }
    log.debug(
      'Android: native CallKit event not received, showing Flutter dialog',
      tag: tag,
    );

    if (incomingCallManager.hasIncomingCall) {
      log.debug('Already showing incoming call, skipping', tag: tag);
      return;
    }

    incomingCallManager.showIncomingCall(callData);
  }

  void _handleAnswer(String callUUID, Map<String, dynamic>? data) {
    log.debug('CallKit answer for $callUUID', tag: tag);
    final callData = data ?? const <String, dynamic>{};
    dispatchCallKitAnswer(
      log: log,
      tag: tag,
      manager: incomingCallManager,
      callData: callData,
    );
    // Deliberately do NOT clear CallKit tracking here — see iOS path
    // comment for the same reasoning (Firestore listener echo window).
  }

  Future<void> _handleEnd(String callUUID, Map<String, dynamic>? data) async {
    log.debug('CallKit end for $callUUID (data=$data)', tag: tag);

    final coordinator = CallNavigationCoordinator();
    if (coordinator.activeController != null) {
      final active = coordinator.activeController!;
      final activeRoomId =
          active.session?.roomId ?? active.session?.callId ?? active.callId;
      final endRoomId = (data?['room_id'] as String?) ??
          (data?['roomName'] as String?) ??
          callUUID;
      final matches =
          (activeRoomId != null && activeRoomId == endRoomId) ||
              (active.callId != null && active.callId == callUUID);

      if (!matches) {
        // Echo from our own cold-start stale-purge endCall — ignore so we
        // don't tear down a live call the user just accepted.
        log.debug(
          'Android CallKit end UUID $callUUID does not match active call '
          '(${active.callId}/$activeRoomId) — ignoring',
          tag: tag,
        );
        return;
      }

      log.debug('Active call found — ending via coordinator', tag: tag);
      await coordinator.endCall();
      return;
    }

    // No active controller — pre-answer reject. Just dismiss any in-app UI;
    // the native plugin already cleaned up its side (it was the producer
    // of this end event), and rejection persistence is handled by the
    // native [RejectCallWorker] cold-start path.
    final callData = data ?? const <String, dynamic>{};
    if (callData.isNotEmpty) {
      log.debug('Pre-answer reject — dismissing Flutter UI', tag: tag);
      incomingCallManager.rejectCallFromCallKit(callData);
      untrack(callData['call_id'] as String?);
      untrack(callData['room_id'] as String?);
      untrack(callData['roomName'] as String?);
    } else {
      log.debug('No active call or end data, dismissing UI', tag: tag);
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

  Future<void> endActiveCall() => _androidCallKitService.endAllCalls();

  void dispose() {
    _eventSub?.cancel();
    clearTracking();
    if (_androidCallKitService.hasActiveCall) {
      log.debug('Ending active Android CallKit call on dispose', tag: tag);
      _androidCallKitService.endAllCalls();
    }
  }
}
