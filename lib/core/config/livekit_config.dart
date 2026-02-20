import 'remote_config_service.dart';

/// LiveKit configuration and constants
class LiveKitConfig {
  static final RemoteConfigService _remoteConfig = RemoteConfigService();

  /// Get LiveKit Server URL from Remote Config (WebSocket)
  /// Production must use wss:// with TLS. Configure in Firebase Remote Config.
  static String get liveKitServerUrl => _remoteConfig.liveKitUrl;

  // =========================================================================
  // CONNECTION OPTIONS
  // =========================================================================
  static const bool enableSimulcast = true;
  static const int maxAudioBitrate = 128000;
  static const int maxVideoBitrate = 2500000;

  // =========================================================================
  // ROOM NAMING
  // =========================================================================
  static const String roomPrefix = 'call_';

  // =========================================================================
  // TIMEOUTS & DELAYS
  // =========================================================================

  /// Timeout waiting for remote participant to join (seconds)
  /// Reduced to 45s (from 60s) for faster timeout detection
  static const int remoteJoinTimeoutSeconds = 45;

  /// ICE connection timeout for initial attempt (seconds).
  /// 30s allows the SDK 3-4 internal reconnection cycles if ICE is slow.
  static const int iceFirstAttemptTimeoutSeconds = 30;

  /// ICE connection timeout for relay-only retry (seconds).
  /// If default ICE fails, we retry with relay-only policy as fallback.
  static const int iceRetryTimeoutSeconds = 15;

  /// SDK publish/subscribe timeout (seconds).
  /// Covers track publish, subscribe, and media device initialization.
  static const int sdkMediaTimeoutSeconds = 15;

  /// SDK peerConnection timeout (seconds).
  static const int sdkPeerConnectTimeoutSeconds = 10;

  /// SDK iceRestart timeout (seconds).
  /// Generous for TURN relay negotiation during mid-call reconnection.
  static const int sdkIceRestartTimeoutSeconds = 15;

  /// Media enable timeout (seconds).
  /// How long to wait for setMicrophoneEnabled/setCameraEnabled to complete.
  static const int mediaEnableTimeoutSeconds = 15;

  /// Delay before disconnect after remote leaves (milliseconds)
  static const int remoteLeftDelayMs = 300;

  /// Cleanup delay after room teardown (seconds).
  /// Gives WebRTC/audio resources time to fully release before next call.
  static const int platformCleanupSeconds = 2;

  /// Interval for polling call quality stats (seconds)
  static const int qualityMonitorIntervalSeconds = 2;

  /// Delay after camera toggle for UI update (milliseconds)
  static const int cameraToggleDelayMs = 100;

  /// Delay while waiting for cleanup to finish (milliseconds)
  static const int cleanupWaitIntervalMs = 50;

  /// Minimum delay between calls to allow server-side cleanup (milliseconds).
  static const int minTimeBetweenCallsMs = 2500;
}
