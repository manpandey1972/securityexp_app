import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Log levels for filtering output
enum LogLevel {
  verbose(0),
  debug(1),
  info(2),
  warning(3),
  error(4),
  none(5);

  final int priority;
  const LogLevel(this.priority);
}

/// Configuration for logging behavior
///
/// This is the single source of truth for all logging decisions.
/// No other file should check `kDebugMode` to decide whether to log.
///
/// To enable verbose/debug logs in release mode (e.g., for field diagnostics):
/// ```dart
/// LogConfig.enableVerboseLogging();
/// ```
/// To disable again:
/// ```dart
/// LogConfig.disableVerboseLogging();
/// ```
class LogConfig {
  /// Current minimum log level - messages below this level are suppressed
  static LogLevel minLevel = kDebugMode ? LogLevel.verbose : LogLevel.warning;

  /// Whether to include timestamps in log output
  static bool includeTimestamp = false;

  /// Whether to log to Crashlytics (only in production)
  static bool logToCrashlytics = !kDebugMode;

  /// Whether to print debug/verbose output to console even in release mode.
  /// When true, [ProductionAppLogger] will print to console in addition to
  /// sending errors to Crashlytics. Useful for field diagnostics.
  static bool forceConsoleOutput = false;

  /// Check if a log level should be output
  static bool shouldLog(LogLevel level) => level.priority >= minLevel.priority;

  /// Enable verbose logging at runtime (works in any build mode).
  ///
  /// Call this from remote config, a hidden debug menu, shake gesture, etc.
  /// to get full diagnostic output in release builds.
  static void enableVerboseLogging() {
    minLevel = LogLevel.verbose;
    forceConsoleOutput = true;
  }

  /// Disable verbose logging and restore production defaults.
  static void disableVerboseLogging() {
    minLevel = kDebugMode ? LogLevel.verbose : LogLevel.warning;
    forceConsoleOutput = false;
  }
}

/// Abstract interface for application-wide logging
///
/// Provides structured logging with different severity levels.
/// Implementations can send logs to different backends (console, analytics, crash reporting).
///
/// Usage:
/// ```dart
/// final logger = sl<AppLogger>();
/// logger.info('User logged in', tag: 'Auth');
/// logger.error('Failed to load data', tag: 'API', error: e, stackTrace: st);
/// ```
abstract class AppLogger {
  /// Logs a verbose message (most detailed, for tracing)
  void verbose(String message, {String? tag, Map<String, dynamic>? data});

  /// Logs a debug message (for development debugging)
  void debug(String message, {String? tag, Map<String, dynamic>? data});

  /// Logs an informational message (general flow tracking)
  void info(String message, {String? tag, Map<String, dynamic>? data});

  /// Logs a warning message (recoverable issues)
  void warning(String message, {String? tag, Map<String, dynamic>? data});

  /// Logs an error message (failures that need attention)
  void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  });
}

/// Debug logger implementation
///
/// Logs to console with emoji prefixes and colors.
/// Used in development and debug builds.
class DebugAppLogger implements AppLogger {
  String _formatMessage(
    String emoji,
    String level,
    String? tag,
    String message,
    Map<String, dynamic>? data,
  ) {
    final buffer = StringBuffer();

    if (LogConfig.includeTimestamp) {
      final now = DateTime.now();
      buffer.write(
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ',
      );
    }

    buffer.write('$emoji $level');
    if (tag != null) {
      buffer.write(' [$tag]');
    }
    buffer.write(' $message');

    if (data != null && data.isNotEmpty) {
      buffer.write(' $data');
    }

    return buffer.toString();
  }

  @override
  void verbose(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.verbose)) return;
    debugPrint(_formatMessage('💬', 'VERBOSE', tag, message, data));
  }

  @override
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.debug)) return;
    debugPrint(_formatMessage('🐛', 'DEBUG', tag, message, data));
  }

  @override
  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.info)) return;
    debugPrint(_formatMessage('ℹ️', 'INFO', tag, message, data));
  }

  @override
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.warning)) return;
    debugPrint(_formatMessage('⚠️', 'WARN', tag, message, data));
  }

  @override
  void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!LogConfig.shouldLog(LogLevel.error)) return;

    debugPrint(_formatMessage('❌', 'ERROR', tag, message, data));

    if (error != null) {
      debugPrint('   Exception: ${error.runtimeType} - $error');
    }

    if (stackTrace != null) {
      debugPrint('   Stack trace:\n$stackTrace');
    }
  }
}

/// Production logger implementation
///
/// Respects [LogConfig] for all logging decisions.
/// By default suppresses verbose/debug in release, but can be enabled at
/// runtime via [LogConfig.enableVerboseLogging] for field diagnostics.
/// Sends warnings/errors to Crashlytics.
class ProductionAppLogger implements AppLogger {
  @override
  void verbose(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.verbose)) return;
    if (LogConfig.forceConsoleOutput) {
      debugPrint('💬 VERBOSE${tag != null ? ' [$tag]' : ''} $message${data != null && data.isNotEmpty ? ' $data' : ''}');
    }
  }

  @override
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.debug)) return;
    if (LogConfig.forceConsoleOutput) {
      debugPrint('🐛 DEBUG${tag != null ? ' [$tag]' : ''} $message${data != null && data.isNotEmpty ? ' $data' : ''}');
    }
  }

  @override
  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.info)) return;

    // Log to Crashlytics breadcrumbs for context
    if (LogConfig.logToCrashlytics) {
      FirebaseCrashlytics.instance.log('[${tag ?? 'App'}] $message');
    }
  }

  @override
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    if (!LogConfig.shouldLog(LogLevel.warning)) return;

    // Log warnings to Crashlytics as breadcrumbs
    if (LogConfig.logToCrashlytics) {
      FirebaseCrashlytics.instance.log(
        '⚠️ [${tag ?? 'App'}] $message ${data ?? ''}',
      );
    }
  }

  @override
  void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!LogConfig.shouldLog(LogLevel.error)) return;

    // Send to Crashlytics for tracking
    if (LogConfig.logToCrashlytics && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: '[${tag ?? 'App'}] $message',
        information:
            data?.entries.map((e) => '${e.key}: ${e.value}').toList() ?? [],
        fatal: false,
      );
    } else if (LogConfig.logToCrashlytics) {
      FirebaseCrashlytics.instance.log('❌ [${tag ?? 'App'}] $message');
    }
  }
}

/// Extension for sanitizing sensitive data in logs
extension LogSanitizer on String {
  /// Redacts a token, showing only first and last 5 characters
  String redactToken() {
    if (length <= 10) return '***';
    return '${substring(0, 5)}...${substring(length - 5)}';
  }

  /// Redacts an email address
  String redactEmail() {
    return replaceAllMapped(
      RegExp(r'(\w)[^@]*(@.*)'),
      (m) => '${m[1]}***${m[2]}',
    );
  }

  /// Redacts a phone number, showing only last 4 digits
  String redactPhone() {
    if (length <= 4) return '***';
    return '***${substring(length - 4)}';
  }

  /// Redacts a user ID, showing only first 4 characters
  String redactUserId() {
    if (length <= 4) return '***';
    return '${substring(0, 4)}...';
  }
}
