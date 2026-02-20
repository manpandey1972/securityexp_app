import 'package:securityexperts_app/core/config/call_config.dart';
import 'package:securityexperts_app/core/config/remote_config_service.dart';
import 'package:securityexperts_app/data/models/call_session.dart';

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
  @override
  String get liveKitTokenGenerationUrl => 'https://example.com';
  @override
  String get liveKitUrl => 'ws://example.com';
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
