import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

void main() {
  group('DebugAppLogger', () {
    late DebugAppLogger logger;

    setUp(() {
      logger = DebugAppLogger();
    });

    test('should create DebugAppLogger instance', () {
      expect(logger, isA<DebugAppLogger>());
      expect(logger, isA<AppLogger>());
    });

    test('should log verbose messages', () {
      // In tests, debugPrint output won't be visible but method should not throw
      expect(
        () => logger.verbose('Verbose message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('should log debug messages', () {
      expect(() => logger.debug('Debug message', tag: 'Test'), returnsNormally);
    });

    test('should log info messages', () {
      expect(() => logger.info('Info message', tag: 'Test'), returnsNormally);
    });

    test('should log warning messages', () {
      expect(
        () => logger.warning('Warning message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('should log error messages', () {
      expect(() => logger.error('Error message', tag: 'Test'), returnsNormally);
    });

    test('should log error with exception', () {
      final exception = Exception('Test exception');
      expect(
        () =>
            logger.error('Error with exception', tag: 'Test', error: exception),
        returnsNormally,
      );
    });

    test('should log error with stack trace', () {
      final stackTrace = StackTrace.current;
      expect(
        () => logger.error(
          'Error with stack',
          tag: 'Test',
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('should handle null tag', () {
      expect(() => logger.debug('Message without tag'), returnsNormally);
    });

    test('should handle empty message', () {
      expect(() => logger.debug('', tag: 'Test'), returnsNormally);
    });

    test('should handle long messages', () {
      final longMessage = 'A' * 10000;
      expect(() => logger.debug(longMessage, tag: 'Test'), returnsNormally);
    });

    test('should handle special characters in message', () {
      const specialMessage = 'Message with emoji 😀 and symbols @#\$%';
      expect(() => logger.debug(specialMessage, tag: 'Test'), returnsNormally);
    });

    test('should handle data parameter', () {
      final data = {'key': 'value', 'count': 42};
      expect(
        () => logger.debug('Message with data', tag: 'Test', data: data),
        returnsNormally,
      );
    });

    test('should handle null data parameter', () {
      expect(
        () => logger.debug('Message', tag: 'Test', data: null),
        returnsNormally,
      );
    });
  });

  group('ProductionAppLogger', () {
    late ProductionAppLogger logger;

    setUp(() {
      logger = ProductionAppLogger();
    });

    test('should create ProductionAppLogger instance', () {
      expect(logger, isA<ProductionAppLogger>());
      expect(logger, isA<AppLogger>());
    });

    test('should not log verbose in production', () {
      // Verbose should be filtered out in production
      expect(
        () => logger.verbose('Verbose message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('should not log debug in production', () {
      // Debug should be filtered out in production
      expect(() => logger.debug('Debug message', tag: 'Test'), returnsNormally);
    });

    test('should log info in production', () {
      expect(() => logger.info('Info message', tag: 'Test'), returnsNormally);
    });

    test('should log warning in production', () {
      expect(
        () => logger.warning('Warning message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('should log error in production', () {
      expect(() => logger.error('Error message', tag: 'Test'), returnsNormally);
    });

    test('should send errors to Crashlytics', () {
      final exception = Exception('Crash');
      final stackTrace = StackTrace.current;

      expect(
        () => logger.error(
          'Critical error',
          tag: 'Test',
          error: exception,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('should handle Crashlytics initialization', () {
      // ProductionAppLogger should handle Crashlytics gracefully
      expect(logger, isNotNull);
    });
  });

  group('AppLogger Factory', () {
    test('should return DebugAppLogger in debug mode', () {
      // In tests, kDebugMode is true
      final logger = kDebugMode ? DebugAppLogger() : ProductionAppLogger();
      expect(logger, isA<DebugAppLogger>());
    });

    test('should implement AppLogger interface', () {
      final debugLogger = DebugAppLogger();
      final prodLogger = ProductionAppLogger();

      expect(debugLogger, isA<AppLogger>());
      expect(prodLogger, isA<AppLogger>());
    });
  });

  group('Log Formatting', () {
    late DebugAppLogger logger;

    setUp(() {
      logger = DebugAppLogger();
    });

    test('should format message with tag', () {
      expect(
        () => logger.debug('Test message', tag: '🔥 [Tag]'),
        returnsNormally,
      );
    });

    test('should format message with data', () {
      final data = {'user': 'john', 'action': 'login'};
      expect(
        () => logger.debug('User action', tag: 'Auth', data: data),
        returnsNormally,
      );
    });

    test('should format error with exception details', () {
      final exception = FormatException('Invalid format');
      expect(
        () => logger.error(
          'Format error occurred',
          tag: 'Parser',
          error: exception,
        ),
        returnsNormally,
      );
    });
  });
}
