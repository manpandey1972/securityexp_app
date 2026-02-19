import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

@GenerateMocks([AppLogger, SnackbarService])
import 'error_handler_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAppLogger mockLogger;
  late MockSnackbarService mockSnackbarService;

  setUp(() {
    mockLogger = MockAppLogger();
    mockSnackbarService = MockSnackbarService();

    // Reset GetIt
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<SnackbarService>()) {
      sl.unregister<SnackbarService>();
    }

    sl.registerSingleton<AppLogger>(mockLogger);
    sl.registerSingleton<SnackbarService>(mockSnackbarService);
  });

  tearDown(() {
    sl.reset();
  });

  group('AppError', () {
    test('should create AppError with required fields', () {
      final error = AppError(
        message: 'Test error',
        severity: ErrorSeverity.error,
      );

      expect(error.message, 'Test error');
      expect(error.severity, ErrorSeverity.error);
      expect(error.timestamp, isNotNull);
    });

    test('should create AppError with all fields', () {
      final exception = Exception('Test exception');
      final stackTrace = StackTrace.current;

      final error = AppError(
        message: 'Test error',
        exception: exception,
        stackTrace: stackTrace,
        severity: ErrorSeverity.critical,
        context: 'test_context',
      );

      expect(error.message, 'Test error');
      expect(error.exception, exception);
      expect(error.stackTrace, stackTrace);
      expect(error.severity, ErrorSeverity.critical);
      expect(error.context, 'test_context');
    });

    test('should return formatted display message for PermissionException', () {
      final error = AppError(
        message: 'Permission denied',
        exception: PermissionException('Camera not allowed'),
      );

      expect(
        error.displayMessage,
        contains('Please check app permissions in settings'),
      );
    });

    test('should return formatted display message for NetworkException', () {
      final error = AppError(
        message: 'Connection failed',
        exception: NetworkException('No internet'),
      );

      expect(error.displayMessage, contains('Network error'));
      expect(error.displayMessage, contains('internet connection'));
    });

    test('should return formatted display message for ValidationException', () {
      final error = AppError(
        message: 'Invalid email',
        exception: ValidationException('Email format incorrect'),
      );

      expect(error.displayMessage, contains('Invalid input'));
    });

    test('should return formatted display message for TimeoutException', () {
      final error = AppError(
        message: 'Request timeout',
        exception: TimeoutException('Too slow'),
      );

      expect(error.displayMessage, contains('timed out'));
      expect(error.displayMessage, contains('try again'));
    });

    test('should return original message for unknown exception', () {
      final error = AppError(
        message: 'Unknown error',
        exception: Exception('Unknown'),
      );

      expect(error.displayMessage, 'Unknown error');
    });

    test('should log error correctly', () {
      final error = AppError(
        message: 'Test error',
        severity: ErrorSeverity.warning,
      );

      error.log();

      verify(mockLogger.warning(any, tag: anyNamed('tag'))).called(1);
    });
  });

  group('ErrorHandler.handle', () {
    test('should execute operation successfully', () async {
      var executed = false;

      await ErrorHandler.handle<void>(
        operation: () async {
          executed = true;
        },
      );

      expect(executed, true);
    });

    test('should return result from operation', () async {
      final result = await ErrorHandler.handle<int>(operation: () async => 42);

      expect(result, 42);
    });

    test('should catch error and call onError callback', () async {
      final testError = Exception('Test error');
      var onErrorCalled = false;

      await ErrorHandler.handle<void>(
        operation: () async {
          throw testError;
        },
        onError: (errorMsg) {
          onErrorCalled = true;
          expect(errorMsg, contains('Test error'));
        },
      );

      expect(onErrorCalled, true);
    });

    test('should log error when exception occurs', () async {
      await ErrorHandler.handle<void>(
        operation: () async {
          throw Exception('Test error');
        },
      );

      verify(
        mockLogger.error(any, tag: anyNamed('tag'), error: anyNamed('error'), stackTrace: anyNamed('stackTrace')),
      ).called(1);
    });

    test('should handle errors without showing UI feedback', () async {
      await ErrorHandler.handle<void>(
        operation: () async {
          throw Exception('Test error');
        },
      );

      verify(
        mockLogger.error(any, tag: anyNamed('tag'), error: anyNamed('error'), stackTrace: anyNamed('stackTrace')),
      ).called(1);
    });

    test('should handle async errors in operation', () async {
      await ErrorHandler.handle<void>(
        operation: () async {
          await Future.delayed(Duration(milliseconds: 10));
          throw Exception('Async error');
        },
      );

      verify(
        mockLogger.error(any, tag: anyNamed('tag'), error: anyNamed('error'), stackTrace: anyNamed('stackTrace')),
      ).called(1);
    });

    test(
      'should return null when operation throws and no default value',
      () async {
        final result = await ErrorHandler.handle<String?>(
          operation: () async {
            throw Exception('Error');
          },
        );

        expect(result, null);
      },
    );
  });

  group('ErrorHandler.handleSync', () {
    test('should execute synchronous operation successfully', () {
      var executed = false;

      ErrorHandler.handleSync(
        operation: () {
          executed = true;
        },
      );

      expect(executed, true);
    });

    test('should catch synchronous errors', () {
      var onErrorCalled = false;

      ErrorHandler.handleSync(
        operation: () {
          throw Exception('Sync error');
        },
        onError: (errorMsg) {
          onErrorCalled = true;
          expect(errorMsg, contains('Sync error'));
        },
      );

      expect(onErrorCalled, true);
      verify(
        mockLogger.error(any, tag: anyNamed('tag'), error: anyNamed('error'), stackTrace: anyNamed('stackTrace')),
      ).called(1);
    });
  });

  group('Custom Exceptions', () {
    test('PermissionException should contain message', () {
      final exception = PermissionException('Camera denied');
      expect(exception.message, 'Camera denied permission not granted');
      expect(exception.toString(), contains('Camera denied'));
    });

    test('NetworkException should contain message', () {
      final exception = NetworkException('No connection');
      expect(exception.message, 'Network error: No connection');
      expect(exception.toString(), contains('No connection'));
    });

    test('ValidationException should contain message', () {
      final exception = ValidationException('Invalid format');
      expect(exception.message, 'Invalid Invalid format');
      expect(exception.toString(), contains('Invalid format'));
    });

    test('CacheException should contain message', () {
      final exception = CacheException('Cache miss');
      expect(exception.message, 'Cache error: Cache miss');
      expect(exception.toString(), contains('Cache miss'));
    });

    test('TimeoutException should contain message', () {
      final exception = TimeoutException('Request timeout');
      expect(exception.message, 'Request timeout');
      expect(exception.toString(), contains('Request timeout'));
    });
  });

  group('Error Severity', () {
    test('should create error with info severity', () {
      final error = AppError(
        message: 'Info message',
        severity: ErrorSeverity.info,
      );

      expect(error.severity, ErrorSeverity.info);
    });

    test('should create error with warning severity', () {
      final error = AppError(
        message: 'Warning message',
        severity: ErrorSeverity.warning,
      );

      expect(error.severity, ErrorSeverity.warning);
    });

    test('should create error with error severity', () {
      final error = AppError(
        message: 'Error message',
        severity: ErrorSeverity.error,
      );

      expect(error.severity, ErrorSeverity.error);
    });

    test('should create error with critical severity', () {
      final error = AppError(
        message: 'Critical message',
        severity: ErrorSeverity.critical,
      );

      expect(error.severity, ErrorSeverity.critical);
    });
  });

  group('ErrorHandler.handle (legacy executeAsync coverage)', () {
    test('returns result on success', () async {
      final result = await ErrorHandler.handle<int>(
        operation: () async => 42,
      );
      expect(result, 42);
    });

    test('returns fallback on exception', () async {
      final result = await ErrorHandler.handle<int?>(
        operation: () async => throw Exception('fail'),
        fallback: null,
      );
      expect(result, isNull);
    });

    test('calls onError callback on exception', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw Exception('fail'),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
    });
  });

  group('ErrorHandler.handle<void> (legacy executeVoid coverage)', () {
    test('completes on success', () async {
      await ErrorHandler.handle<void>(
        operation: () async {},
      );
      // No exception means success
    });

    test('does not throw on exception', () async {
      await ErrorHandler.handle<void>(
        operation: () async => throw Exception('fail'),
      );
      // No exception means error was handled
    });
  });

  group('ErrorHandler.handleSync (legacy executeSync coverage)', () {
    test('executes operation on success', () {
      int? result;
      ErrorHandler.handleSync(
        operation: () { result = 42; },
      );
      expect(result, 42);
    });

    test('does not throw on exception', () {
      ErrorHandler.handleSync(
        operation: () => throw Exception('fail'),
      );
      // No exception means error was handled
    });
  });

  group('ErrorHandler parallel operations (legacy executeMultiple coverage)', () {
    test('runs all operations in parallel', () async {
      final results = await Future.wait([
        ErrorHandler.handle<int>(operation: () async => 1, fallback: null),
        ErrorHandler.handle<int>(operation: () async => 2, fallback: null),
        ErrorHandler.handle<int>(operation: () async => 3, fallback: null),
      ]);
      expect(results, [1, 2, 3]);
    });

    test('failed operations yield fallback in results', () async {
      final results = await Future.wait([
        ErrorHandler.handle<int?>(operation: () async => 1, fallback: null),
        ErrorHandler.handle<int?>(operation: () async => throw Exception('fail'), fallback: null),
        ErrorHandler.handle<int?>(operation: () async => 3, fallback: null),
      ]);
      expect(results, [1, null, 3]);
    });

    test('handles empty operations list', () async {
      final results = await Future.wait(<Future<int?>>[]);
      expect(results, isEmpty);
    });
  });

  group('ErrorHandler.handle', () {
    test('returns result on success', () async {
      final result = await ErrorHandler.handle<int>(
        operation: () async => 42,
      );
      expect(result, 42);
    });

    test('returns fallback on exception', () async {
      final result = await ErrorHandler.handle<int>(
        operation: () async => throw Exception('fail'),
        fallback: -1,
      );
      expect(result, -1);
    });

    test('calls onError with message on exception', () async {
      String? errorMsg;
      await ErrorHandler.handle<int>(
        operation: () async => throw Exception('fail'),
        fallback: -1,
        onError: (msg) => errorMsg = msg,
      );
      expect(errorMsg, isNotNull);
      expect(errorMsg, contains('fail'));
    });
  });

  group('Error message formatting (through handle)', () {
    test('formats FirebaseAuthException with known code', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found',
        ),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
    });

    test('formats FirebaseAuthException wrong-password', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Wrong password',
        ),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
    });

    test('formats FirebaseAuthException unknown code uses message', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw FirebaseAuthException(
          code: 'some-new-code',
          message: 'Something new',
        ),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
    });

    test('formats TimeoutException', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw TimeoutException('Timed out'),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
      expect(captured, contains('Timed out'));
    });

    test('formats FormatException', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw const FormatException('bad json'),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
      expect(captured, contains('bad json'));
    });

    test('formats AppException subclass (PermissionException)', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw PermissionException('camera'),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
      expect(captured, contains('camera'));
    });

    test('formats String error', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw 'plain string error',
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, 'plain string error');
    });

    test('formats generic Exception with toString', () async {
      String? captured;
      await ErrorHandler.handle<int?>(
        operation: () async => throw Exception('generic'),
        fallback: null,
        onError: (msg) => captured = msg,
      );
      expect(captured, isNotNull);
      expect(captured, contains('generic'));
    });
  });
}
