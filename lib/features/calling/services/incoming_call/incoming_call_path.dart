import 'dart:async';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import '../call_navigation_coordinator.dart';
import '../incoming_call_manager.dart';

/// Per-platform incoming-call routing strategy.
///
/// Each platform (iOS / Android / Web) implements its own subclass to wire
/// the appropriate native CallKit listener (or none) and decide whether
/// the in-app Flutter incoming-call dialog should be shown for a given
/// Firestore event. The public [IncomingCallStrategy] facade selects and
/// delegates to the right path at runtime.
abstract class IncomingCallPath {
  IncomingCallPath() : log = sl<AppLogger>();

  final AppLogger log;
  late final IncomingCallManager incomingCallManager =
      sl<IncomingCallManager>();

  /// Logger tag for this path. Each subclass uses its own value so messages
  /// can be filtered by platform in `adb logcat` / device logs.
  String get tag;

  /// Wire native listeners and perform any one-shot startup work (e.g.
  /// pre-tracking cold-start CallKit ids on Android). Safe to call once.
  Future<void> initialize();

  /// Handle a `livekit_rooms` document change delivered by the Firestore
  /// listener. The implementation decides whether to show the in-app
  /// Flutter incoming-call dialog or suppress it because the native CallKit
  /// UI is already (or imminently) handling the call.
  Future<void> handleIncomingCall(Map<String, dynamic> callData);
}

/// Shared CallKit-call tracking used by both iOS and Android paths to
/// suppress the in-app Flutter dialog for calls already being handled by
/// the native CallKit UI. Tracked entries expire after [_expiration] to
/// prevent unbounded growth from stale ids.
mixin CallKitTrackingMixin {
  static const Duration _expiration = Duration(minutes: 2);

  final Map<String, DateTime> _tracked = <String, DateTime>{};

  void trackCallKitCall(String? id) {
    if (id != null && id.isNotEmpty) {
      _tracked[id] = DateTime.now();
    }
  }

  bool isHandledByCallKit(String id) {
    _cleanupExpired();
    return _tracked.containsKey(id);
  }

  Iterable<String> get trackedIds => _tracked.keys;

  void untrack(String? id) {
    if (id != null) _tracked.remove(id);
  }

  void clearTracking() => _tracked.clear();

  void _cleanupExpired() {
    final now = DateTime.now();
    _tracked.removeWhere((_, t) => now.difference(t) > _expiration);
  }
}

/// Mute event de-duplication. CallKit can emit `CXSetMutedCallAction`
/// multiple times in rapid succession for a single user-initiated mute
/// (especially from car displays); collapse echoes within 500ms.
mixin CallKitMuteDedupMixin {
  DateTime _lastMuteTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _lastMuteValue;

  bool isDuplicateMuteEvent(bool muted) {
    final now = DateTime.now();
    final isDup = _lastMuteValue == muted &&
        now.difference(_lastMuteTime).inMilliseconds < 500;
    if (!isDup) {
      _lastMuteTime = now;
      _lastMuteValue = muted;
    }
    return isDup;
  }
}

/// Extract a call id from any of the keys that the various producers
/// (server callable, VoIP push, Android FCM service) put it under.
String? extractCallKey(Map<String, dynamic> data) {
  return data['call_id'] as String? ??
      data['room_id'] as String? ??
      data['roomName'] as String? ??
      data['callId'] as String?;
}

/// Whether the Firestore call doc carries a terminal status that means we
/// should drop the event entirely (no UI, no acceptance attempt).
bool isStaleCallStatus(String? status) {
  return status == 'ended' ||
      status == 'rejected' ||
      status == 'cancelled' ||
      status == 'missed';
}

/// Shared body of CallKit answer handling: validates we have call data,
/// then triggers acceptance via [IncomingCallManager].
void dispatchCallKitAnswer({
  required AppLogger log,
  required String tag,
  required IncomingCallManager manager,
  required Map<String, dynamic> callData,
}) {
  if (callData.isEmpty) {
    log.warning('No call data for answered call', tag: tag);
    return;
  }
  log.debug('Calling acceptCallFromCallKit...', tag: tag);
  manager.acceptCallFromCallKit(callData);
}

/// Shared body of CallKit mute handling. Syncs the requested mute state
/// onto the active controller's media manager, avoiding redundant toggles.
void dispatchCallKitMute({
  required AppLogger log,
  required String tag,
  required bool isMuted,
}) {
  final controller = CallNavigationCoordinator().activeController;
  if (controller == null) {
    log.warning('No active controller for mute', tag: tag);
    return;
  }
  final current = controller.mediaManager?.isMuted.value ?? false;
  if (current == isMuted) {
    log.debug('Mute already in sync: $isMuted', tag: tag);
    return;
  }
  log.debug('Syncing mute state: $current -> $isMuted', tag: tag);
  // syncToCallKit: false avoids a feedback loop — CallKit already knows
  // the new state since the action originated from it.
  controller.setMicrophoneMuted(isMuted, syncToCallKit: false);
}
