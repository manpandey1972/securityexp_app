import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Severity levels for errors
enum ErrorSeverity { info, warning, error, critical }

/// Unified app error model
class AppError {
  final String message;
  final dynamic exception;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final String? context;
  final DateTime timestamp;

  AppError({
    required this.message,
    this.exception,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    this.context,
  }) : timestamp = DateTime.now();

  /// Get user-friendly error message based on exception type
  String get displayMessage {
    if (exception is PermissionException) {
      return '$message\nPlease check app permissions in settings.';
    }
    if (exception is NetworkException) {
      return 'Network error: $message\nPlease check your internet connection.';
    }
    if (exception is ValidationException) {
      return 'Invalid input: $message';
    }
    if (exception is CacheException) {
      return 'Cache error: $message';
    }
    if (exception is TimeoutException) {
      return 'Operation timed out: $message\nPlease try again.';
    }

    return message;
  }

  /// Log error for debugging
  void log() {
    final logger = sl<AppLogger>();
    const tag = 'ErrorHandler';

    final severityTag = switch (severity) {
      ErrorSeverity.info => 'INFO',
      ErrorSeverity.warning => 'WARN',
      ErrorSeverity.error => 'ERROR',
      ErrorSeverity.critical => 'CRITICAL',
    };

    final contextTag = context ?? 'Unknown';
    logger.warning('$severityTag [$contextTag] $message', tag: tag);

    if (exception != null) {
      logger.error('Exception: ${exception.runtimeType}\n$exception', tag: tag);
    }

    if (stackTrace != null) {
      logger.debug('Stack trace:\n$stackTrace', tag: tag);
    }
  }

  @override
  String toString() =>
      'AppError(severity: $severity, context: $context, message: $message)';
}

/// Centralized error handling service
class ErrorHandler {
  /// Execute async operation with automatic error handling and user feedback
  ///
  /// Returns the result of [fn] or null if an error occurs.
  @Deprecated('Use ErrorHandler.handle() instead. '
      'Example: await ErrorHandler.handle<T>(operation: () => fn(), fallback: null)')
  static Future<T?> executeAsync<T>({
    required String operation,
    required Future<T> Function() fn,
    bool showSnackbar = true,
    String? context,
    void Function(AppError)? onError,
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      final error = _parseError(
        e,
        stackTrace: st,
        operation: operation,
        context: context,
      );
      error.log();

      onError?.call(error);

      if (showSnackbar) {
        SnackbarService.show(error.displayMessage);
      }

      return null;
    }
  }

  /// Execute void async operation with error handling
  ///
  /// Returns true if successful, false if an error occurred.
  @Deprecated('Use ErrorHandler.handle<void>() instead. '
      'Example: await ErrorHandler.handle<void>(operation: () => fn())')
  static Future<bool> executeVoid({
    required String operation,
    required Future<void> Function() fn,
    bool showSnackbar = true,
    String? context,
    void Function(AppError)? onError,
  }) async {
    try {
      await fn();
      return true;
    } catch (e, st) {
      final error = _parseError(
        e,
        stackTrace: st,
        operation: operation,
        context: context,
      );
      error.log();

      onError?.call(error);

      if (showSnackbar) {
        SnackbarService.show(error.displayMessage);
      }

      return false;
    }
  }

  /// Execute sync operation with error handling
  ///
  /// Returns the result of [fn] or null if an error occurs.
  @Deprecated('Use ErrorHandler.handleSync() instead')
  static T? executeSync<T>({
    required String operation,
    required T Function() fn,
    bool showSnackbar = true,
    String? context,
    void Function(AppError)? onError,
  }) {
    try {
      return fn();
    } catch (e, st) {
      final error = _parseError(
        e,
        stackTrace: st,
        operation: operation,
        context: context,
      );
      error.log();

      onError?.call(error);

      if (showSnackbar) {
        SnackbarService.show(error.displayMessage);
      }

      return null;
    }
  }

  /// Modern async error handling with fallback support
  ///
  /// Usage:
  /// final result = await ErrorHandler.handle`<User?>`(
  ///   operation: () => fetchUser(),
  ///   fallback: null,
  ///   onError: (error) => print('Error: $error'),
  /// );
  static Future<T> handle<T>({
    required Future<T> Function() operation,
    T? fallback,
    void Function(String)? onError,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final errorMsg = _formatErrorMessage(e);
      final logger = sl<AppLogger>();
      logger.error('handle failed: $errorMsg', error: e, stackTrace: stackTrace, tag: 'ErrorHandler');
      onError?.call(errorMsg);
      return fallback as T;
    }
  }

  /// Modern sync error handling with fallback support
  ///
  /// Usage:
  /// final result = ErrorHandler.handleSync(
  ///   operation: () => parseJson(),
  ///   onError: (error) => print('Error: $error'),
  /// );
  static void handleSync({
    required void Function() operation,
    void Function(String)? onError,
  }) {
    try {
      operation();
    } catch (e, stackTrace) {
      final errorMsg = _formatErrorMessage(e);
      final logger = sl<AppLogger>();
      logger.error('handleSync failed: $errorMsg', error: e, stackTrace: stackTrace, tag: 'ErrorHandler');
      onError?.call(errorMsg);
    }
  }

  /// Helper to format error messages from exceptions
  static String _formatErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Exception) return error.toString();
    return 'Unknown error: $error';
  }

  /// Execute multiple async operations in parallel with error handling
  ///
  /// Returns a list of results. Failed operations have null values.
  @Deprecated('Use Future.wait with ErrorHandler.handle() for each operation instead')
  static Future<List<T?>> executeMultiple<T>({
    required String operation,
    required List<Future<T> Function()> operations,
    bool showSnackbar = true,
    String? context,
  }) async {
    return Future.wait(
      operations.map(
        (op) => executeAsync(
          operation: operation,
          fn: op,
          showSnackbar: showSnackbar,
          context: context,
        ),
      ),
    );
  }

  /// Handle custom errors directly
  static void handleError(
    dynamic error,
    StackTrace? stackTrace, {
    required String operation,
    String? context,
    bool showSnackbar = true,
    void Function(AppError)? onError,
  }) {
    final appError = _parseError(
      error,
      stackTrace: stackTrace,
      operation: operation,
      context: context,
    );
    appError.log();

    onError?.call(appError);

    if (showSnackbar) {
      SnackbarService.show(appError.displayMessage);
    }
  }

  /// Parse different exception types into AppError
  ///
  /// Uses typed exception handling for Firebase errors (auth, firestore)
  /// instead of fragile string matching.
  static AppError _parseError(
    dynamic exception, {
    StackTrace? stackTrace,
    required String operation,
    String? context,
  }) {
    String message = 'Error during $operation';
    ErrorSeverity severity = ErrorSeverity.error;

    if (exception is String) {
      message = exception;
    } else if (exception is AppException) {
      message = exception.message;
      severity = exception.severity;
    } else if (exception is FirebaseAuthException) {
      // Firebase Auth errors — use error codes for reliable classification
      severity = ErrorSeverity.warning;
      message = switch (exception.code) {
        'user-not-found' => 'Account not found.',
        'wrong-password' || 'invalid-credential' => 'Invalid credentials.',
        'email-already-in-use' => 'Email already in use.',
        'weak-password' => 'Password is too weak.',
        'invalid-email' => 'Invalid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Network error. Please check your connection.',
        'requires-recent-login' => 'Please sign in again to continue.',
        _ => exception.message ?? 'Authentication error.',
      };
    } else if (exception is FirebaseException) {
      // Firestore and other Firebase errors — use error codes
      severity = ErrorSeverity.warning;
      message = switch (exception.code) {
        'permission-denied' => 'Permission denied. Please check access rights.',
        'not-found' => 'Resource not found.',
        'unavailable' => 'Service temporarily unavailable. Please try again.',
        'deadline-exceeded' => '$operation timed out.',
        'already-exists' => 'Resource already exists.',
        'resource-exhausted' => 'Too many requests. Please try again later.',
        'cancelled' => 'Operation cancelled.',
        'unauthenticated' => 'Please sign in to continue.',
        _ => exception.message ?? 'A Firebase error occurred.',
      };
    } else if (exception is TimeoutException) {
      message = '$operation timed out';
      severity = ErrorSeverity.warning;
    } else if (exception is FormatException) {
      message = 'Invalid format: ${exception.message}';
      severity = ErrorSeverity.warning;
    } else if (exception is Exception) {
      message = exception.toString();
    }
    // Note: non-Exception errors (Error subclasses) fall through
    // with the default message, which is appropriate since those
    // are programming errors, not user-facing issues.

    return AppError(
      message: message,
      exception: exception,
      stackTrace: stackTrace,
      severity: severity,
      context: context ?? 'Unknown',
    );
  }
}

// ============================================================================
// CUSTOM EXCEPTION CLASSES
// ============================================================================

/// Base exception for app-specific errors
abstract class AppException implements Exception {
  final String message;
  final ErrorSeverity severity;
  final dynamic originalError;

  AppException(
    this.message, {
    this.severity = ErrorSeverity.error,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Permission-related errors
class PermissionException extends AppException {
  PermissionException(String permission, {String? customMessage})
    : super(
        customMessage ?? '$permission permission not granted',
        severity: ErrorSeverity.warning,
      );
}

/// Network-related errors
class NetworkException extends AppException {
  NetworkException(String details, {String? customMessage})
    : super(
        customMessage ?? 'Network error: $details',
        severity: ErrorSeverity.error,
      );
}

/// Validation errors
class ValidationException extends AppException {
  ValidationException(String field, {String? customMessage})
    : super(customMessage ?? 'Invalid $field', severity: ErrorSeverity.warning);
}

/// Cache-related errors
class CacheException extends AppException {
  CacheException(String operation, {String? customMessage})
    : super(
        customMessage ?? 'Cache error: $operation',
        severity: ErrorSeverity.warning,
      );
}

/// Authentication errors
class AuthException extends AppException {
  AuthException(String details, {String? customMessage})
    : super(
        customMessage ?? 'Authentication error: $details',
        severity: ErrorSeverity.error,
      );
}

/// Database operation errors
class DatabaseException extends AppException {
  DatabaseException(String operation, {String? customMessage})
    : super(
        customMessage ?? 'Database error: $operation',
        severity: ErrorSeverity.error,
      );
}

/// File operation errors
class FileException extends AppException {
  FileException(String operation, {String? customMessage})
    : super(
        customMessage ?? 'File error: $operation',
        severity: ErrorSeverity.error,
      );
}

/// Media/stream errors
class MediaException extends AppException {
  MediaException(String operation, {String? customMessage})
    : super(
        customMessage ?? 'Media error: $operation',
        severity: ErrorSeverity.error,
      );
}
