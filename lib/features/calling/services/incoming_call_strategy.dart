import 'dart:async';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import 'incoming_call/android_incoming_call_path.dart';
import 'incoming_call/default_incoming_call_path.dart';
import 'incoming_call/incoming_call_path.dart';
import 'incoming_call/ios_incoming_call_path.dart';
import 'platform_utils.dart';

/// Thin per-platform facade for incoming-call routing.
///
/// **Why this exists:**
/// Selects the appropriate [IncomingCallPath] implementation at construction
/// time (iOS / Android / default) and forwards the small public surface
/// that the rest of the app depends on. Each path lives in its own file
/// under `services/incoming_call/` so the platform-specific quirks
/// (VoIP push on iOS, cold-start ACTIVE_CALLS handling on Android, no-op
/// fallback on web) are no longer tangled together in a single god-class.
///
/// **Call flow recap:**
/// 1. Backend `createCall()` writes a doc to Firestore.
/// 2. If app-level notifications are on, backend also sends VoIP push
///    (iOS) or FCM data message (Android).
/// 3. The Firestore listener is ALWAYS active as the fallback path.
///
/// **Duplicate prevention** is owned by each path via
/// `CallKitTrackingMixin` — tracked call ids expire after 2 minutes.
class IncomingCallStrategy {
  factory IncomingCallStrategy() => _instance;
  IncomingCallStrategy._internal() : _path = _createPath();

  static final IncomingCallStrategy _instance =
      IncomingCallStrategy._internal();

  final IncomingCallPath _path;
  bool _isInitialized = false;

  static IncomingCallPath _createPath() {
    if (PlatformUtils.isIOS) return IosIncomingCallPath();
    if (PlatformUtils.isAndroid) return AndroidIncomingCallPath();
    return DefaultIncomingCallPath();
  }

  /// Underlying per-platform implementation. Exposed for tests and the
  /// small number of platform-specific bridges (e.g. iOS VoIP push) that
  /// need to invoke methods only present on one path.
  IncomingCallPath get path => _path;

  /// Initialise native listeners. Safe to call more than once.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _path.initialize();
  }

  /// Handle an incoming-call Firestore event. The platform path decides
  /// whether to show the in-app Flutter dialog or suppress it in favour
  /// of the native CallKit UI.
  Future<void> handleIncomingCall(Map<String, dynamic> callData) =>
      _path.handleIncomingCall(callData);

  /// iOS-only: bridge a VoIP push (CallKit UI already shown by native
  /// PushKitManager) to the Dart side. No-op on other platforms.
  Future<void> handleVoIPPushCall({
    required String callId,
    required String callerId,
    required String callerName,
    required bool hasVideo,
    String? roomName,
  }) async {
    final p = _path;
    if (p is IosIncomingCallPath) {
      await p.handleVoIPPushCall(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        hasVideo: hasVideo,
        roomName: roomName,
      );
    } else {
      sl<AppLogger>().warning(
        'VoIP push received on non-iOS platform',
        tag: 'IncomingCallStrategy',
      );
    }
  }
}
