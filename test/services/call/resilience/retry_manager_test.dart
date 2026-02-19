import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/calling/services/resilience/retry_manager.dart';

import '../../../mocks/mock_call_logger.dart';

void main() {
  group('RetryManager', () {
    late MockCallLogger mockLogger;
    late RetryManager retryManager;

    setUp(() {
      mockLogger = MockCallLogger();
      retryManager = RetryManager(
        logger: mockLogger,
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 50),
          exponentialBackoff: true,
        ),
      );
    });

    tearDown(() {
      mockLogger.clear();
    });

    test('succeeds on first attempt', () async {
      int callCount = 0;

      final result = await retryManager.execute(
        operation: () async {
          callCount++;
          return 'success';
        },
      );

      expect(result.succeeded, true);
      expect(result.value, 'success');
      expect(result.attempts, 1);
      expect(callCount, 1);
    });

    test('retries and succeeds on second attempt', () async {
      int callCount = 0;

      final result = await retryManager.execute(
        operation: () async {
          callCount++;
          if (callCount == 1) {
            throw Exception('First attempt failed');
          }
          return 'success';
        },
      );

      expect(result.succeeded, true);
      expect(result.value, 'success');
      expect(result.attempts, 2);
      expect(callCount, 2);
    });

    test('fails after max attempts', () async {
      int callCount = 0;

      final result = await retryManager.execute(
        operation: () async {
          callCount++;
          throw Exception('Always fails');
        },
      );

      expect(result.succeeded, false);
      expect(result.value, isNull);
      expect(result.attempts, 3);
      expect(callCount, 3);
      expect(result.lastError, isA<Exception>());
    });

    test('calls onRetry callback before each retry', () async {
      int retryCallbacks = 0;

      await retryManager.execute(
        operation: () async {
          throw Exception('Fail');
        },
        onRetry: (attempt, delay) {
          retryCallbacks++;
        },
      );

      expect(retryCallbacks, 2); // Called before 2nd and 3rd attempts
    });

    test('stops retrying for non-retryable errors', () async {
      int callCount = 0;

      final result = await retryManager.execute(
        operation: () async {
          callCount++;
          throw Exception('Permission denied');
        },
        shouldRetry: (error) => !error.toString().contains('Permission'),
      );

      expect(result.succeeded, false);
      expect(result.attempts, 1); // Only tried once
      expect(callCount, 1);
    });

    test('executeOrNull returns null on failure', () async {
      final result = await retryManager.executeOrNull(
        operation: () async {
          throw Exception('Fail');
        },
      );

      expect(result, isNull);
    });

    test('executeOrThrow throws on failure', () async {
      expect(
        () async => await retryManager.executeOrThrow(
          operation: () async {
            throw Exception('Fail');
          },
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('exponential backoff increases delay', () async {
      final delays = <Duration>[];

      await retryManager.execute(
        operation: () async {
          throw Exception('Fail');
        },
        onRetry: (attempt, delay) {
          delays.add(delay);
        },
      );

      expect(delays.length, 2);
      // Second delay should be longer than first
      expect(delays[1].inMilliseconds, greaterThan(delays[0].inMilliseconds));
    });

    test('linear backoff uses same delay', () async {
      final linearRetry = RetryManager(
        logger: mockLogger,
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 50),
          exponentialBackoff: false,
        ),
      );

      final delays = <Duration>[];

      await linearRetry.execute(
        operation: () async {
          throw Exception('Fail');
        },
        onRetry: (attempt, delay) {
          delays.add(delay);
        },
      );

      expect(delays.length, 2);
      expect(delays[0], delays[1]); // Same delay
    });

    test('records total duration', () async {
      final result = await retryManager.execute(
        operation: () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'success';
        },
      );

      expect(result.totalDuration.inMilliseconds, greaterThanOrEqualTo(10));
    });
  });

  group('RetryPolicy', () {
    test('identifies network errors', () {
      expect(
        RetryPolicy.isNetworkError(Exception('Network connection failed')),
        true,
      );
      expect(RetryPolicy.isNetworkError(Exception('Socket timeout')), true);
      expect(RetryPolicy.isNetworkError(Exception('Host unreachable')), true);
      expect(RetryPolicy.isNetworkError(Exception('Some other error')), false);
    });

    test('identifies temporary errors', () {
      expect(
        RetryPolicy.isTemporaryError(
          Exception('Service temporary unavailable'),
        ),
        true,
      );
      expect(RetryPolicy.isTemporaryError(Exception('Server is busy')), true);
      expect(RetryPolicy.isTemporaryError(Exception('System overload')), true);
      expect(RetryPolicy.isTemporaryError(Exception('Invalid input')), false);
    });

    test('identifies auth errors', () {
      expect(RetryPolicy.isAuthError(Exception('Permission denied')), true);
      expect(RetryPolicy.isAuthError(Exception('Unauthorized access')), true);
      expect(RetryPolicy.isAuthError(Exception('Forbidden')), true);
      expect(RetryPolicy.isAuthError(Exception('Network error')), false);
    });

    test('shouldRetryCallError policy', () {
      expect(
        RetryPolicy.shouldRetryCallError(Exception('Network failed')),
        true,
      );
      expect(
        RetryPolicy.shouldRetryCallError(Exception('Temporary error')),
        true,
      );
      expect(
        RetryPolicy.shouldRetryCallError(Exception('Permission denied')),
        false,
      );
      expect(
        RetryPolicy.shouldRetryCallError(Exception('Unauthorized')),
        false,
      );
    });
  });

  group('RetryConfig', () {
    test('copyWith creates modified config', () {
      const original = RetryConfig(maxAttempts: 3);

      final modified = original.copyWith(
        maxAttempts: 5,
        initialDelay: const Duration(seconds: 1),
      );

      expect(modified.maxAttempts, 5);
      expect(modified.initialDelay, const Duration(seconds: 1));
      expect(
        modified.backoffMultiplier,
        original.backoffMultiplier,
      ); // Unchanged
    });
  });
}
