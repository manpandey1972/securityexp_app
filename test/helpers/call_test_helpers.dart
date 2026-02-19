import 'package:greenhive_app/core/config/call_config.dart';
import 'package:greenhive_app/core/config/remote_config_service.dart';
import 'package:greenhive_app/data/models/call_session.dart';

/// Test helper utilities for call system tests
///
/// Provides common test data, fixtures, and utility functions.

/// Mock RemoteConfigService for testing
class MockRemoteConfigService implements RemoteConfigService {
  final int? _callTimeoutSeconds;
  final int? _connectionTimeoutSeconds;
  final int? _maxSetupRetries;
  final String _logLevel;

  MockRemoteConfigService({
    int callTimeoutSeconds = 1,
    int connectionTimeoutSeconds = 1,
    int maxSetupRetries = 2,
    String logLevel = 'info',
    bool useLiveKit = true, // Ignored, kept for backward compat
  }) : _callTimeoutSeconds = callTimeoutSeconds,
       _connectionTimeoutSeconds = connectionTimeoutSeconds,
       _maxSetupRetries = maxSetupRetries,
       _logLevel = logLevel;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  int get callTimeoutSeconds => _callTimeoutSeconds ?? 1;
  @override
  int get connectionTimeoutSeconds => _connectionTimeoutSeconds ?? 1;
  @override
  int get maxSetupRetries => _maxSetupRetries ?? 2;
  @override
  String get logLevel => _logLevel;

  // Implement other required getters with defaults
  @override
  int get cleanupIntervalMinutes => 5;
  @override
  bool get enableAnalytics => true;
  @override
  bool get enableAudioDeviceSelection => true;
  @override
  bool get enableCameraSwitching => true;
  @override
  bool get enableCallRecording => false;
  @override
  bool get enableCrashReporting => true;
  @override
  bool get enableErrorLogging => true;
  @override
  bool get enableScreenSharing => false;
  @override
  bool get enableVideoCalling => true;
  @override
  bool get enableWakelock => true;
  @override
  String get liveKitTokenGenerationUrl => 'https://example.com';
  @override
  String get liveKitUrl => 'ws://example.com';
  @override
  List<String> getAudioDevicePriorityList() => ['speaker'];
  @override
  String get audioDefaultFallback => 'speaker';
  @override
  String get audioDevicePriority => 'speaker';
  @override
  String get cloudFunctionBaseUrl => 'https://example.com';
  @override
  String get cloudRunBaseUrl => 'https://example.com';
  @override
  String get turnCredential => 'pass';
  @override
  String get turnServerUrls => 'example.com:3478';
  @override
  String get turnUsername => 'user';
  @override
  String get messageCallSetupFailed => 'Setup failed';
  @override
  String get messageConnectionTimeout => 'Connection timeout';
  @override
  String get messagePermissionDenied => 'Permission denied';
  @override
  String get messageCameraTimeout => 'Camera timeout';
  @override
  double get localPreviewHeight => 160.0;
  @override
  double get localPreviewWidth => 120.0;
  @override
  int get videoMinFrameRate => 30;
  @override
  int get videoMinHeight => 720;
  @override
  int get videoMinWidth => 1280;
  @override
  int get animationQuickMs => 200;
  @override
  int get animationSlowMs => 500;
  @override
  int get animationStandardMs => 300;
  @override
  int get callDurationTimerIntervalSeconds => 1;
  @override
  int get controlsAutoHideSeconds => 5;
  @override
  int get rendererMonitorIntervalSeconds => 5;
  @override
  int get incomingCallDebounceMs => 500;
  @override
  int get offerExpirationSeconds => 60;
  @override
  int get iosRebuildDelayMs => 150;
  @override
  int get postConnectionDelayMs => 100;
  @override
  int get rendererMaxRetryAttempts => 3;
  @override
  int get rendererPrewarmDelayMs => 200;
  @override
  int get rendererRetryDelayMs => 100;
  @override
  int get streamRecreationDelayMs => 500;
  @override
  Map<String, dynamic> getAllValues() => {};
}

/// Creates a test CallConfig with shorter timeouts for faster tests
CallConfig createTestCallConfig({
  int callTimeoutSeconds = 1,
  int connectionTimeoutSeconds = 1,
  int maxSetupRetries = 2,
}) {
  final mockRemoteConfig = MockRemoteConfigService(
    callTimeoutSeconds: callTimeoutSeconds,
    connectionTimeoutSeconds: connectionTimeoutSeconds,
    maxSetupRetries: maxSetupRetries,
  );
  return CallConfig(remoteConfig: mockRemoteConfig);
}

/// Creates a test CallSession for outgoing calls
CallSession createTestOutgoingCallSession({
  String? callId,
  String? calleeId,
  bool isVideo = true,
}) {
  return CallSession(
    callId: callId ?? 'test-call-id',
    roomId: callId ?? 'test-room-id',
    isCaller: true,
    calleeId: calleeId ?? 'test-callee-id',
    callerId: 'test-caller-id',
    isVideo: isVideo,
  );
}

/// Creates a test CallSession for incoming calls
CallSession createTestIncomingCallSession({
  String? callId,
  String? callerId,
  bool isVideo = true,
}) {
  return CallSession(
    callId: callId ?? 'test-call-id',
    roomId: callId ?? 'test-room-id',
    isCaller: false,
    calleeId: 'test-callee-id',
    callerId: callerId ?? 'test-caller-id',
    isVideo: isVideo,
  );
}

/// Waits for a condition to become true with timeout
///
/// Polls the condition every 50ms until it returns true or timeout is reached.
/// Returns true if condition became true, false if timeout.
Future<bool> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    if (condition()) {
      return true;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  return condition();
}

/// Waits for an async condition to become true with timeout
Future<bool> waitForAsyncCondition(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    if (await condition()) {
      return true;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  return await condition();
}

/// Delays execution for testing timing-dependent behavior
Future<void> testDelay([Duration? duration]) async {
  await Future.delayed(duration ?? const Duration(milliseconds: 100));
}
