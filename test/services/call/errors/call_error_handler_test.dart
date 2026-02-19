import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/errors/call_errors.dart';
import 'package:greenhive_app/core/errors/call_error_handler.dart';

import '../../../mocks/mock_call_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Register AppLogger for error handling
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(DebugAppLogger());
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('CallError Types', () {
    test('CallNetworkError is recoverable', () {
      final error = CallNetworkError('Connection lost');

      expect(error.isRecoverable, true);
      expect(error.message, 'Connection lost');
      expect(error.userMessage, contains('Network'));
    });

    test('CallTimeoutError is recoverable', () {
      final error = CallTimeoutError(const Duration(seconds: 30));

      expect(error.isRecoverable, true);
      expect(error.timeout, const Duration(seconds: 30));
      expect(error.userMessage, contains('timed out'));
    });

    test('CallPermissionError is not recoverable', () {
      final error = CallPermissionError('camera', 'Camera access denied');

      expect(error.isRecoverable, false);
      expect(error.permission, 'camera');
      expect(error.userMessage, contains('camera permission'));
    });

    test('CallStateError has correct information', () {
      final error = CallStateError('ended', 'toggleVideo');

      expect(error.isRecoverable, false);
      expect(error.currentState, 'ended');
      expect(error.attemptedOperation, 'toggleVideo');
      expect(error.message, contains('Cannot toggleVideo in state: ended'));
    });

    test('CallMediaError has user-friendly message', () {
      final error = CallMediaError('Failed to access camera');

      expect(error.isRecoverable, false);
      expect(error.userMessage, contains('audio/video'));
    });

    test('CallConfigurationError indicates setup problem', () {
      final error = CallConfigurationError('Invalid TURN server URL');

      expect(error.isRecoverable, false);
      expect(error.userMessage, contains('not properly configured'));
    });
  });

  group('CallErrorHandler', () {
    late MockCallLogger mockLogger;
    late CallErrorHandler errorHandler;

    setUp(() {
      mockLogger = MockCallLogger();
      errorHandler = CallErrorHandler(mockLogger);
    });

    tearDown(() {
      mockLogger.clear();
    });

    test('handles recoverable network error', () {
      final error = CallNetworkError('Connection failed');
      int retryCount = 0;

      final handled = errorHandler.handleError(
        error,
        onRetry: () => retryCount++,
      );

      expect(handled, true);
      expect(retryCount, 1);
      expect(mockLogger.errorCount, 0);
      expect(mockLogger.infoCount, 1);
    });

    test('handles timeout error without retry', () {
      final error = CallTimeoutError(const Duration(seconds: 30));

      final handled = errorHandler.handleError(error);

      expect(handled, false); // Timeout ends the call
      expect(mockLogger.errorCount, 0);
      expect(mockLogger.infoCount, 1);
    });

    test('handles fatal permission error', () {
      final error = CallPermissionError('microphone', 'Access denied');

      final handled = errorHandler.handleError(error);

      expect(handled, false);
      expect(mockLogger.errorCount, greaterThanOrEqualTo(1));
      expect(mockLogger.warningCount, greaterThanOrEqualTo(1));
    });

    test('handles fatal configuration error', () {
      final error = CallConfigurationError('Missing API key');

      final handled = errorHandler.handleError(error);

      expect(handled, false);
      expect(
        mockLogger.errorCount,
        greaterThanOrEqualTo(2),
      ); // Multiple error logs
    });

    test('fromException classifies network errors', () {
      final exception = Exception('Network connection failed');

      final error = CallErrorHandler.fromException(exception);

      expect(error, isA<CallNetworkError>());
      expect(error.isRecoverable, true);
    });

    test('fromException classifies timeout errors', () {
      final exception = Exception('Operation timeout after 30 seconds');

      final error = CallErrorHandler.fromException(exception);

      expect(error, isA<CallTimeoutError>());
    });

    test('fromException classifies permission errors', () {
      final exception = Exception('Camera permission denied');

      final error = CallErrorHandler.fromException(exception);

      expect(error, isA<CallMediaError>());
    });

    test('fromException returns CallError as-is', () {
      final originalError = CallNetworkError('Test error');

      final error = CallErrorHandler.fromException(originalError);

      expect(error, same(originalError));
    });

    test('fromException defaults to unknown error', () {
      final exception = Exception('Something unexpected happened');

      final error = CallErrorHandler.fromException(exception);

      expect(error, isA<CallUnknownError>());
      expect(error.isRecoverable, false);
    });
  });

  group('CallError toString', () {
    test('includes message and code', () {
      final error = CallNetworkError('Connection lost', code: 'NET_001');

      expect(error.toString(), contains('Connection lost'));
      expect(error.toString(), contains('NET_001'));
    });

    test('works without code', () {
      final error = CallNetworkError('Connection lost');

      expect(error.toString(), contains('Connection lost'));
      expect(error.toString(), isNot(contains('null')));
    });
  });
}
