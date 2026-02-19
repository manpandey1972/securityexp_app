import 'package:shake_detector/shake_detector.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';

/// Manages shake gesture detection for toggling verbose logging.
///
/// When the device is shaken, verbose logging is toggled on/off and a
/// notification is shown. This is useful for field debugging in release builds.
class ShakeHandler {
  static const String _tag = 'ShakeHandler';
  static bool _isVerboseLoggingEnabled = false;

  /// Initialize shake gesture detection for debug logging toggle.
  ///
  /// Call this during app startup after service locator is initialized.
  static void setup() {
    ShakeDetector.autoStart(
      onShake: _onPhoneShake,
    );

    sl<AppLogger>().debug(
      'Shake detector initialized - shake device to toggle verbose logging',
      tag: _tag,
    );
  }

  /// Handle phone shake event
  static void _onPhoneShake() {
    _isVerboseLoggingEnabled = !_isVerboseLoggingEnabled;

    if (_isVerboseLoggingEnabled) {
      LogConfig.enableVerboseLogging();
      sl<AppLogger>().info(
        '🔥 VERBOSE LOGGING ENABLED - all debug output visible',
        tag: _tag,
      );
      SnackbarService.show('🔥 Verbose logging enabled', duration: const Duration(seconds: 3));
    } else {
      LogConfig.disableVerboseLogging();
      sl<AppLogger>().info(
        '🔒 Verbose logging disabled - back to production defaults',
        tag: _tag,
      );
      SnackbarService.show('🔒 Verbose logging disabled', duration: const Duration(seconds: 3));
    }
  }
}

