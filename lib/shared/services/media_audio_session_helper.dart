import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Helper class to configure iOS audio session for media playback.
///
/// On iOS, the audio session determines where audio is routed.
/// This helper ensures media (videos, audio messages) play through
/// the speaker at full volume by default, while still allowing
/// automatic routing to Bluetooth/headsets when connected.
///
/// ## Audio Session Configuration Flow
///
/// 1. **App Launch**: Audio session is NOT configured (deferred to on-demand)
/// 2. **Media Playback**: Call [configureForMediaPlayback] before playing video/audio
/// 3. **Starting Call**: Call [configureForWebRTC] to switch to call mode
/// 4. **During Call**: Audio is managed by native AudioSessionManager
/// 5. **Call Ended**: iOS CallKit handles deactivation via native callbacks
///
/// ## Usage
///
/// ```dart
/// // Before playing a video message
/// await MediaAudioSessionHelper.configureForMediaPlayback();
/// videoController.play();
///
/// // Before starting a call (if not using CallKit flow)
/// await MediaAudioSessionHelper.configureForWebRTC();
/// ```
///
/// Note: When using CallKit for calls (iOS), the native AudioSessionManager
/// handles audio configuration in the didActivate callback, so you typically
/// don't need to call configureForWebRTC() manually.
class MediaAudioSessionHelper {
  static const _platform = MethodChannel('com.greenhive.call/audio');
  static const String _tag = 'MediaAudioSessionHelper';

  /// Configure the iOS audio session for media playback.
  ///
  /// This switches the audio session category to .playback with
  /// defaultToSpeaker option, ensuring audio plays through the
  /// speaker at full volume. If Bluetooth or headphones are
  /// connected, audio routes to them automatically.
  ///
  /// Call this before playing any media (video, audio messages).
  static Future<void> configureForMediaPlayback() async {
    if (kIsWeb) return;
    if (!Platform.isIOS) return;

    try {
      await _platform.invokeMethod('configureForMediaPlayback');
    } catch (e, stackTrace) {
      sl<AppLogger>().error(
        'Error configuring for media playback',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Restore the audio session for WebRTC calls.
  ///
  /// This switches the audio session to .playAndRecord with .voiceChat mode,
  /// optimized for two-way voice communication with echo cancellation.
  ///
  /// ## When to call this method
  ///
  /// - **Direct WebRTC calls** (without CallKit): Call before starting media capture
  /// - **After media playback** before a call: Call to restore call-appropriate settings
  /// - **Not needed with CallKit**: Native AudioSessionManager handles configuration
  ///   in the CXProviderDelegate.didActivate callback
  ///
  /// ## Important
  ///
  /// For iOS calls using CallKit, the audio session is configured by the native
  /// AudioSessionManager when CallKit activates the audio session. Calling this
  /// method is only necessary for:
  /// 1. Non-CallKit call flows (rare)
  /// 2. After playing media during an active call (to restore call settings)
  static Future<void> configureForWebRTC() async {
    if (kIsWeb) return;
    if (!Platform.isIOS) return;

    try {
      await _platform.invokeMethod('configureForWebRTC');
    } catch (_) {
      // Silently fail - not critical
    }
  }
}
