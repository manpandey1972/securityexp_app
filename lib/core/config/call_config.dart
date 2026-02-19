import 'package:greenhive_app/core/config/remote_config_service.dart';

/// Configuration for the call system
///
/// Centralizes all configurable parameters for calls including timeouts,
/// retry logic, and feature flags. All values come from RemoteConfigService.
class CallConfig {
  final RemoteConfigService _remoteConfig;

  /// Maximum time to wait for callee to answer before timing out
  Duration get callTimeout =>
      Duration(seconds: _remoteConfig.callTimeoutSeconds);

  /// Time to wait before attempting to reconnect after connection loss
  Duration get reconnectInterval =>
      Duration(seconds: _remoteConfig.connectionTimeoutSeconds);

  /// Maximum number of reconnection attempts before giving up
  int get maxReconnectAttempts => 3;

  /// Initial delay for exponential backoff retry strategy
  Duration get retryInitialDelay => const Duration(seconds: 2);

  /// Multiplier for exponential backoff between retries
  double get retryBackoffMultiplier => 2.0;

  /// Maximum number of retry attempts for recoverable errors
  int get maxRetryAttempts => _remoteConfig.maxSetupRetries;

  /// Enable detailed debug logging
  bool get enableDebugLogging => _remoteConfig.logLevel == 'debug';

  /// Enable connection quality monitoring
  bool get enableQualityMonitoring => true;

  CallConfig({RemoteConfigService? remoteConfig})
    : _remoteConfig = remoteConfig ?? RemoteConfigService();
}
