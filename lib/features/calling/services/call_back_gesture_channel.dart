import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';

import 'package:securityexperts_app/features/calling/services/call_navigation_coordinator.dart';

/// Bridge between the native Android back gesture interceptor (registered in
/// `MainActivity.kt`) and the Dart-side call coordinator.
///
/// Why this exists:
///   On Android 14+ with predictive back, Flutter only claims back-gesture
///   handling when its root Navigator can pop. While a call is overlaid on
///   the home page (the root route), `canPop` is false, so the system
///   finishes the Activity directly — `FlutterJNI` detaches and in-flight
///   `RTCVideoView` frames crash the process. The native side therefore
///   registers an `OnBackInvokedCallback` at `PRIORITY_OVERLAY` (above
///   Flutter's default) and forwards back gestures to Dart through this
///   channel only while a call is active.
class CallBackGestureChannel {
  CallBackGestureChannel._() {
    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler(_onMethodCall);
    }
  }

  static final CallBackGestureChannel instance = CallBackGestureChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.greenhive.call/backgesture');

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onBackInvoked') {
      debugPrint('[CallBackGesture] onBackInvoked from native');
      final coordinator = CallNavigationCoordinator();
      if (!coordinator.isCallActive) {
        debugPrint('[CallBackGesture] no active call, ignoring');
        return null;
      }
      if (coordinator.isMinimized) {
        // Already minimized — the user pressed back again. We've already
        // unregistered the native callback in this state, so this branch
        // is defensive only.
        debugPrint('[CallBackGesture] already minimized, ignoring');
        return null;
      }
      debugPrint('[CallBackGesture] minimizing call');
      coordinator.minimize();
    }
    return null;
  }

  /// Tell the native side to register/unregister the back gesture
  /// interceptor. Call with `true` when a call becomes active (full-screen)
  /// and `false` when it ends OR when it is already minimised (so the next
  /// back gesture moves the task to the background normally).
  Future<void> setCallActive(bool active) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setCallActive', {'active': active});
    } catch (e) {
      debugPrint('[CallBackGesture] setCallActive($active) failed: $e');
    }
  }
}
