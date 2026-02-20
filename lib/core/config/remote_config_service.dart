import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Service to manage dynamic configuration via Firebase Remote Config
/// Allows runtime changes without app updates
class RemoteConfigService {
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'RemoteConfigService';

  static final RemoteConfigService _instance = RemoteConfigService._internal();

  factory RemoteConfigService() {
    return _instance;
  }

  RemoteConfigService._internal();

  late FirebaseRemoteConfig _remoteConfig;

  /// Initialize Remote Config with default values
  Future<void> initialize() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await _remoteConfig.setDefaults(_getDefaultValues());

      // Fetch and activate remote config
      await _remoteConfig.fetchAndActivate();

      _log.info('Initialized successfully', tag: _tag);
    } catch (e) {
      _log.error('Initialization error', tag: _tag, error: e);
    }
  }

  /// Get all default configuration values
  Map<String, dynamic> _getDefaultValues() {
    return {
      // ==================== CALL TIMING ====================
      'call_timeout_seconds': 30,
      'connection_timeout_seconds': 30,

      // ==================== PERFORMANCE TUNING ====================
      'max_setup_retries': 2,

      // ==================== LIVEKIT CONFIGURATION ====================
      // SECURITY: Production must use wss:// with a valid TLS certificate.
      // Configure the actual URL in Firebase Remote Config.
      // This fallback uses wss:// to prevent unencrypted signaling.
      'livekit_url': 'wss://livekit.gogreenhive.com',
      'livekit_tokengeneration_url':
          'https://generatelivekittokenfunction-cnpzidasqa-uc.a.run.app',

      // ==================== ANALYTICS & LOGGING ====================
      'log_level': 'info', // debug, info, warning, error
    };
  }

  // ==================== CALL TIMING ====================
  int get callTimeoutSeconds => _getInt('call_timeout_seconds');
  int get connectionTimeoutSeconds => _getInt('connection_timeout_seconds');

  // ==================== PERFORMANCE TUNING ====================
  int get maxSetupRetries => _getInt('max_setup_retries');

  // ==================== LIVEKIT CONFIGURATION ====================
  /// LiveKit WebSocket server URL
  String get liveKitUrl => _getString('livekit_url');

  /// LiveKit token generation Cloud Function URL
  String get liveKitTokenGenerationUrl =>
      _getString('livekit_tokengeneration_url');

  // ==================== ANALYTICS & LOGGING ====================
  String get logLevel => _getString('log_level');

  // ==================== PRIVATE HELPERS ====================
  int _getInt(String key) {
    try {
      final value = _remoteConfig.getValue(key);
      if (value.source == ValueSource.valueStatic) {
        return _getDefaultValues()[key] as int? ?? 0;
      }
      return int.parse(value.asString());
    } catch (e) {
      _log.warning('Error getting int', tag: _tag, data: {'key': key});
      return _getDefaultValues()[key] as int? ?? 0;
    }
  }

  String _getString(String key) {
    try {
      final value = _remoteConfig.getValue(key);
      if (value.source == ValueSource.valueStatic) {
        return _getDefaultValues()[key] as String? ?? '';
      }
      return value.asString();
    } catch (e) {
      _log.warning('Error getting string', tag: _tag, data: {'key': key});
      return _getDefaultValues()[key] as String? ?? '';
    }
  }

  /// Manual refresh for testing (usually happens automatically)
  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      _log.info('Refreshed successfully', tag: _tag);
    } catch (e) {
      _log.error('Refresh error', tag: _tag, error: e);
    }
  }

  /// Get all current values (for debugging)
  Map<String, dynamic> getAllValues() {
    return {
      'callTimeoutSeconds': callTimeoutSeconds,
      'connectionTimeoutSeconds': connectionTimeoutSeconds,
      'maxSetupRetries': maxSetupRetries,
      'liveKitUrl': liveKitUrl,
      'liveKitTokenGenerationUrl': liveKitTokenGenerationUrl,
      'logLevel': logLevel,
    };
  }
}
