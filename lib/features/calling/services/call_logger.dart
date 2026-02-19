import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Abstract interface for call system logging
///
/// Provides structured logging with different severity levels.
/// Implementations can send logs to different backends (console, analytics, crash reporting).
abstract class CallLogger {
  /// Logs an informational message
  ///
  /// Used for general flow tracking and debugging.
  void info(String message, [Map<String, dynamic>? data]);

  /// Logs a warning message
  ///
  /// Used for recoverable issues or unexpected states.
  void warning(String message, [Map<String, dynamic>? data]);

  /// Logs an error message
  ///
  /// Used for exceptions and failures that need attention.
  void error(String message, dynamic error, [StackTrace? stackTrace]);

  /// Logs a debug message
  ///
  /// Used for verbose debugging information.
  /// May be disabled in production builds.
  void debug(String message, [Map<String, dynamic>? data]);
}

/// Debug logger implementation
///
/// Uses AppLogger as backend. Used in development and debug builds.
class DebugCallLogger implements CallLogger {
  static const String _tag = 'Call';

  AppLogger get _log => sl<AppLogger>();

  @override
  void info(String message, [Map<String, dynamic>? data]) {
    _log.info('$message ${data != null ? data.toString() : ""}', tag: _tag);
  }

  @override
  void warning(String message, [Map<String, dynamic>? data]) {
    _log.warning('$message ${data != null ? data.toString() : ""}', tag: _tag);
  }

  @override
  void error(String message, dynamic error, [StackTrace? stackTrace]) {
    _log.error(message, error: error, stackTrace: stackTrace, tag: _tag);
  }

  @override
  void debug(String message, [Map<String, dynamic>? data]) {
    _log.debug('$message ${data != null ? data.toString() : ""}', tag: _tag);
  }
}

/// Production logger implementation
///
/// Uses AppLogger as backend and sends errors to Firebase Crashlytics.
/// Used in release builds for production monitoring.
class ProductionCallLogger implements CallLogger {
  static const String _tag = 'Call';

  AppLogger get _log => sl<AppLogger>();

  @override
  void info(String message, [Map<String, dynamic>? data]) {
    _log.info('$message ${data != null ? data.toString() : ""}', tag: _tag);
  }

  @override
  void warning(String message, [Map<String, dynamic>? data]) {
    _log.warning('$message ${data != null ? data.toString() : ""}', tag: _tag);

    // Log warnings to Crashlytics as non-fatal
    FirebaseCrashlytics.instance.log('Warning: $message ${data ?? ""}');
  }

  @override
  void error(String message, dynamic error, [StackTrace? stackTrace]) {
    _log.error(message, error: error, stackTrace: stackTrace, tag: _tag);

    // Send to Crashlytics for tracking
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: message,
      information: ['call_system'],
      fatal: false,
    );
  }

  @override
  void debug(String message, [Map<String, dynamic>? data]) {
    _log.debug('$message ${data != null ? data.toString() : ""}', tag: _tag);
  }
}
