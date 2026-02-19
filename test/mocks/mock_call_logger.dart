import 'package:greenhive_app/features/calling/services/call_logger.dart';

/// Mock implementation of CallLogger for testing
///
/// Captures all log messages for verification in tests.
class MockCallLogger implements CallLogger {
  final List<LogEntry> logs = [];

  int infoCount = 0;
  int warningCount = 0;
  int errorCount = 0;
  int debugCount = 0;

  @override
  void info(String message, [Map<String, dynamic>? data]) {
    infoCount++;
    logs.add(LogEntry(LogLevel.info, message, data: data));
  }

  @override
  void warning(String message, [Map<String, dynamic>? data]) {
    warningCount++;
    logs.add(LogEntry(LogLevel.warning, message, data: data));
  }

  @override
  void error(String message, dynamic error, [StackTrace? stackTrace]) {
    errorCount++;
    logs.add(
      LogEntry(LogLevel.error, message, error: error, stackTrace: stackTrace),
    );
  }

  @override
  void debug(String message, [Map<String, dynamic>? data]) {
    debugCount++;
    logs.add(LogEntry(LogLevel.debug, message, data: data));
  }

  /// Get all logs of a specific level
  List<LogEntry> getLogsOfLevel(LogLevel level) {
    return logs.where((log) => log.level == level).toList();
  }

  /// Check if a message was logged
  bool hasLogWithMessage(String message) {
    return logs.any((log) => log.message.contains(message));
  }

  /// Get the last log entry
  LogEntry? get lastLog => logs.isNotEmpty ? logs.last : null;

  /// Clear all logs and counters
  void clear() {
    logs.clear();
    infoCount = 0;
    warningCount = 0;
    errorCount = 0;
    debugCount = 0;
  }
}

/// Log level enum
enum LogLevel { info, warning, error, debug }

/// Log entry structure
class LogEntry {
  final LogLevel level;
  final String message;
  final Map<String, dynamic>? data;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  LogEntry(this.level, this.message, {this.data, this.error, this.stackTrace})
    : timestamp = DateTime.now();

  @override
  String toString() {
    return '[$level] $message ${data ?? ""} ${error ?? ""}';
  }
}
