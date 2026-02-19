import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

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
      'offer_expiration_seconds': 60,
      'cleanup_interval_minutes': 5,
      'incoming_call_debounce_ms': 500,

      // ==================== UI/UX TIMING ====================
      'controls_auto_hide_seconds': 5,
      'call_duration_timer_interval_seconds': 1,
      'renderer_monitor_interval_seconds': 5,
      'animation_quick_ms': 200,
      'animation_standard_ms': 300,
      'animation_slow_ms': 500,

      // ==================== CAMERA/VIDEO SETTINGS ====================
      'video_min_width': 1280,
      'video_min_height': 720,
      'video_min_frame_rate': 30,
      'local_preview_width': 120.0,
      'local_preview_height': 160.0,
      'renderer_max_retry_attempts': 3,
      'renderer_retry_delay_ms': 100,
      'stream_recreation_delay_ms': 500,

      // ==================== AUDIO SETTINGS ====================
      'audio_device_priority': 'bluetooth,headset,earpiece,speaker',
      'audio_default_fallback': 'speaker',

      // ==================== FEATURE FLAGS ====================
      'enable_video_calling': true,
      'enable_screen_sharing': false,
      'enable_call_recording': false,
      'enable_camera_switching': true,
      'enable_audio_device_selection': true,
      'enable_wakelock': true,
      // ==================== BACKEND CONFIGURATION ====================
      'cloud_run_base_url':
          'https://greenhive-service-1054913877112.us-west1.run.app',
      'cloud_function_base_url':
          'https://us-west1-greenhive-prod.cloudfunctions.net/roomMessageNotificationTrigger',
      'turn_server_urls': '',
      // SECURITY: TURN credentials must be configured in Firebase Remote Config
      // Do NOT hardcode credentials here - they will be fetched from Remote Config
      'turn_username': '',
      'turn_credential': '',

      // ==================== LIVEKIT CONFIGURATION ====================
      // SECURITY: Production must use wss:// with a valid TLS certificate.
      // Configure the actual URL in Firebase Remote Config.
      // This fallback uses wss:// to prevent unencrypted signaling.
      'livekit_url': 'wss://livekit.gogreenhive.com',
      'livekit_tokengeneration_url':
          'https://generatelivekittokenfunction-cnpzidasqa-uc.a.run.app',

      // ==================== ERROR & MESSAGING ====================
      'message_camera_timeout':
          'Camera/Microphone access timed out. Check permissions.',
      'message_permission_denied':
          'Camera/Microphone permission denied or not found.',
      'message_connection_timeout':
          'Connection timeout. Peer may not be available.',
      'message_call_setup_failed':
          'Call setup failed. Please check your camera/microphone permissions.',
      'enable_error_logging': true,

      // ==================== PERFORMANCE TUNING ====================
      'max_setup_retries': 2,
      'renderer_prewarm_delay_ms': 200,
      'ios_rebuild_delay_ms': 150,
      'post_connection_delay_ms': 100,

      // ==================== ANALYTICS & LOGGING ====================
      'enable_analytics': true,
      'enable_crash_reporting': true,
      'log_level': 'info', // debug, info, warning, error
    };
  }

  // ==================== CALL TIMING ====================
  int get callTimeoutSeconds => _getInt('call_timeout_seconds');
  int get connectionTimeoutSeconds => _getInt('connection_timeout_seconds');
  int get offerExpirationSeconds => _getInt('offer_expiration_seconds');
  int get cleanupIntervalMinutes => _getInt('cleanup_interval_minutes');
  int get incomingCallDebounceMs => _getInt('incoming_call_debounce_ms');

  // ==================== UI/UX TIMING ====================
  int get controlsAutoHideSeconds => _getInt('controls_auto_hide_seconds');
  int get callDurationTimerIntervalSeconds =>
      _getInt('call_duration_timer_interval_seconds');
  int get rendererMonitorIntervalSeconds =>
      _getInt('renderer_monitor_interval_seconds');
  int get animationQuickMs => _getInt('animation_quick_ms');
  int get animationStandardMs => _getInt('animation_standard_ms');
  int get animationSlowMs => _getInt('animation_slow_ms');

  // ==================== CAMERA/VIDEO SETTINGS ====================
  int get videoMinWidth => _getInt('video_min_width');
  int get videoMinHeight => _getInt('video_min_height');
  int get videoMinFrameRate => _getInt('video_min_frame_rate');
  double get localPreviewWidth => _getDouble('local_preview_width');
  double get localPreviewHeight => _getDouble('local_preview_height');
  int get rendererMaxRetryAttempts => _getInt('renderer_max_retry_attempts');
  int get rendererRetryDelayMs => _getInt('renderer_retry_delay_ms');
  int get streamRecreationDelayMs => _getInt('stream_recreation_delay_ms');

  // ==================== AUDIO SETTINGS ====================
  String get audioDevicePriority => _getString('audio_device_priority');
  String get audioDefaultFallback => _getString('audio_default_fallback');

  /// Parse audio device priority into list
  List<String> getAudioDevicePriorityList() {
    return audioDevicePriority.split(',').map((e) => e.trim()).toList();
  }

  // ==================== FEATURE FLAGS ====================
  bool get enableVideoCalling => _getBool('enable_video_calling');
  bool get enableScreenSharing => _getBool('enable_screen_sharing');
  bool get enableCallRecording => _getBool('enable_call_recording');
  bool get enableCameraSwitching => _getBool('enable_camera_switching');
  bool get enableAudioDeviceSelection =>
      _getBool('enable_audio_device_selection');
  bool get enableWakelock => _getBool('enable_wakelock');

  // ==================== BACKEND CONFIGURATION ====================
  /// Cloud Run base URL for chat, API, and main services
  String get cloudRunBaseUrl => _getString('cloud_run_base_url');

  /// Cloud Function base URL for serverless functions (notifications, etc.)
  String get cloudFunctionBaseUrl => _getString('cloud_function_base_url');

  String get turnServerUrls => _getString('turn_server_urls');
  String get turnUsername => _getString('turn_username');
  String get turnCredential => _getString('turn_credential');

  // ==================== LIVEKIT CONFIGURATION ====================
  /// LiveKit WebSocket server URL
  String get liveKitUrl => _getString('livekit_url');

  /// LiveKit token generation Cloud Function URL
  String get liveKitTokenGenerationUrl =>
      _getString('livekit_tokengeneration_url');

  // ==================== ERROR & MESSAGING ====================
  String get messageCameraTimeout => _getString('message_camera_timeout');
  String get messagePermissionDenied => _getString('message_permission_denied');
  String get messageConnectionTimeout =>
      _getString('message_connection_timeout');
  String get messageCallSetupFailed => _getString('message_call_setup_failed');
  bool get enableErrorLogging => _getBool('enable_error_logging');

  // ==================== PERFORMANCE TUNING ====================
  int get maxSetupRetries => _getInt('max_setup_retries');
  int get rendererPrewarmDelayMs => _getInt('renderer_prewarm_delay_ms');
  int get iosRebuildDelayMs => _getInt('ios_rebuild_delay_ms');
  int get postConnectionDelayMs => _getInt('post_connection_delay_ms');

  // ==================== ANALYTICS & LOGGING ====================
  bool get enableAnalytics => _getBool('enable_analytics');
  bool get enableCrashReporting => _getBool('enable_crash_reporting');
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

  double _getDouble(String key) {
    try {
      final value = _remoteConfig.getValue(key);
      if (value.source == ValueSource.valueStatic) {
        return _getDefaultValues()[key] as double? ?? 0.0;
      }
      return double.parse(value.asString());
    } catch (e) {
      _log.warning('Error getting double', tag: _tag, data: {'key': key});
      return _getDefaultValues()[key] as double? ?? 0.0;
    }
  }

  bool _getBool(String key) {
    try {
      final value = _remoteConfig.getValue(key);
      if (value.source == ValueSource.valueStatic) {
        return _getDefaultValues()[key] as bool? ?? false;
      }
      final stringValue = value.asString().toLowerCase();
      return stringValue == 'true' || stringValue == '1';
    } catch (e) {
      _log.warning('Error getting bool', tag: _tag, data: {'key': key});
      return _getDefaultValues()[key] as bool? ?? false;
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
      'offerExpirationSeconds': offerExpirationSeconds,
      'cleanupIntervalMinutes': cleanupIntervalMinutes,
      'controlsAutoHideSeconds': controlsAutoHideSeconds,
      'enableVideoCalling': enableVideoCalling,
      'enableAudioDeviceSelection': enableAudioDeviceSelection,
      'logLevel': logLevel,
    };
  }
}
