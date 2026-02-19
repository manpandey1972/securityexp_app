import 'dart:async';
import 'package:greenhive_app/features/calling/services/call_logger.dart';

/// Configuration for retry behavior
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool exponentialBackoff;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.exponentialBackoff = true,
  });

  RetryConfig copyWith({
    int? maxAttempts,
    Duration? initialDelay,
    double? backoffMultiplier,
    Duration? maxDelay,
    bool? exponentialBackoff,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      initialDelay: initialDelay ?? this.initialDelay,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
      maxDelay: maxDelay ?? this.maxDelay,
      exponentialBackoff: exponentialBackoff ?? this.exponentialBackoff,
    );
  }
}

/// Result of a retry operation
class RetryResult<T> {
  final T? value;
  final int attempts;
  final bool succeeded;
  final Object? lastError;
  final Duration totalDuration;

  const RetryResult({
    this.value,
    required this.attempts,
    required this.succeeded,
    this.lastError,
    required this.totalDuration,
  });

  bool get failed => !succeeded;
}

/// Manages retry logic with exponential backoff
///
/// Automatically retries failed operations with configurable backoff strategy.
class RetryManager {
  final CallLogger logger;
  final RetryConfig config;

  RetryManager({required this.logger, RetryConfig? config})
    : config = config ?? const RetryConfig();

  /// Execute an operation with retry logic
  ///
  /// [operation] - The async function to retry
  /// [shouldRetry] - Optional predicate to determine if error is retryable
  /// [onRetry] - Optional callback called before each retry attempt
  Future<RetryResult<T>> execute<T>({
    required Future<T> Function() operation,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    final startTime = DateTime.now();
    int attempt = 0;
    Object? lastError;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        logger.info('Retry attempt $attempt/${config.maxAttempts}');

        final result = await operation();
        final duration = DateTime.now().difference(startTime);

        logger.info('Operation succeeded on attempt $attempt');

        return RetryResult<T>(
          value: result,
          attempts: attempt,
          succeeded: true,
          totalDuration: duration,
        );
      } catch (error) {
        lastError = error;
        logger.warning('Attempt $attempt failed: $error');

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          logger.info('Error is not retryable, stopping');
          break;
        }

        // Don't wait after last attempt
        if (attempt >= config.maxAttempts) {
          break;
        }

        // Calculate delay for next attempt
        final delay = _calculateDelay(attempt);
        logger.info('Waiting ${delay.inMilliseconds}ms before retry');

        if (onRetry != null) {
          onRetry(attempt, delay);
        }

        await Future.delayed(delay);
      }
    }

    final duration = DateTime.now().difference(startTime);
    logger.error('Operation failed after $attempt attempts', lastError, null);

    return RetryResult<T>(
      attempts: attempt,
      succeeded: false,
      lastError: lastError,
      totalDuration: duration,
    );
  }

  /// Calculate delay for next retry attempt
  Duration _calculateDelay(int attemptNumber) {
    if (!config.exponentialBackoff) {
      return config.initialDelay;
    }

    // Exponential backoff: initialDelay * (multiplier ^ (attempt - 1))
    final delayMs =
        config.initialDelay.inMilliseconds *
        (config.backoffMultiplier.toInt() << (attemptNumber - 1));

    final delay = Duration(milliseconds: delayMs);

    // Cap at max delay
    return delay > config.maxDelay ? config.maxDelay : delay;
  }

  /// Execute operation with retry and return null on failure
  Future<T?> executeOrNull<T>({
    required Future<T> Function() operation,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    final result = await execute<T>(
      operation: operation,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );

    return result.value;
  }

  /// Execute operation with retry and throw on failure
  Future<T> executeOrThrow<T>({
    required Future<T> Function() operation,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    final result = await execute<T>(
      operation: operation,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );

    if (result.succeeded) {
      return result.value as T;
    } else {
      throw result.lastError ??
          Exception('Operation failed after ${result.attempts} attempts');
    }
  }
}

/// Determines if an error is retryable based on common patterns
class RetryPolicy {
  /// Check if error is a network-related issue that can be retried
  static bool isNetworkError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('unreachable');
  }

  /// Check if error is a temporary service issue
  static bool isTemporaryError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('temporary') ||
        errorString.contains('unavailable') ||
        errorString.contains('busy') ||
        errorString.contains('overload');
  }

  /// Check if error is a permission/auth issue (not retryable)
  static bool isAuthError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('denied');
  }

  /// Default retry policy for call operations
  static bool shouldRetryCallError(Object error) {
    // Don't retry auth errors
    if (isAuthError(error)) {
      return false;
    }

    // Retry network and temporary errors
    return isNetworkError(error) || isTemporaryError(error);
  }
}
