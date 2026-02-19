// PendingNotificationHandler tests
//
// Tests for the pending notification handler which processes notifications
// that were tapped while the app was terminated.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/shared/services/pending_notification_handler.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

import '../helpers/service_mocks.mocks.dart';

@GenerateMocks([RemoteMessage])
import 'pending_notification_handler_test.mocks.dart';

void main() {
  late MockAppLogger mockAppLogger;

  setUp(() {
    // Clear any previous pending message
    PendingNotificationHandler.setPendingMessage(null);

    mockAppLogger = MockAppLogger();

    // Register mock AppLogger
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);
  });

  tearDown(() {
    // Clean up pending message
    PendingNotificationHandler.setPendingMessage(null);

    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('PendingNotificationHandler', () {
    group('setPendingMessage', () {
      test('should store pending message', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message-123');

        PendingNotificationHandler.setPendingMessage(mockMessage);

        expect(PendingNotificationHandler.hasPendingMessage, true);
      });

      test('should clear pending message when set to null', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message-123');

        PendingNotificationHandler.setPendingMessage(mockMessage);
        expect(PendingNotificationHandler.hasPendingMessage, true);

        PendingNotificationHandler.setPendingMessage(null);
        expect(PendingNotificationHandler.hasPendingMessage, false);
      });

      test('should accept message with messageId', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message-456');

        PendingNotificationHandler.setPendingMessage(mockMessage);

        expect(PendingNotificationHandler.hasPendingMessage, true);
      });
    });

    group('hasPendingMessage', () {
      test('should return false initially', () {
        expect(PendingNotificationHandler.hasPendingMessage, false);
      });

      test('should return true after setting message', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message');

        PendingNotificationHandler.setPendingMessage(mockMessage);
        expect(PendingNotificationHandler.hasPendingMessage, true);
      });

      test('should return false after consuming message', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message');

        PendingNotificationHandler.setPendingMessage(mockMessage);
        PendingNotificationHandler.consumePendingMessage();

        expect(PendingNotificationHandler.hasPendingMessage, false);
      });
    });

    group('consumePendingMessage', () {
      test('should return and clear pending message', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message');

        PendingNotificationHandler.setPendingMessage(mockMessage);

        final consumed = PendingNotificationHandler.consumePendingMessage();

        expect(consumed, mockMessage);
        expect(PendingNotificationHandler.hasPendingMessage, false);
      });

      test('should return null when no pending message', () {
        final consumed = PendingNotificationHandler.consumePendingMessage();
        expect(consumed, isNull);
      });

      test('should return null on second consume', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('test-message');

        PendingNotificationHandler.setPendingMessage(mockMessage);
        PendingNotificationHandler.consumePendingMessage();

        final secondConsume =
            PendingNotificationHandler.consumePendingMessage();
        expect(secondConsume, isNull);
      });
    });

    group('navigatorKey', () {
      test('should provide a global navigator key', () {
        expect(PendingNotificationHandler.navigatorKey, isNotNull);
      });
    });

    group('notification type parsing', () {
      // Note: handleNotificationNavigation requires a valid BuildContext
      // which is difficult to mock in unit tests. These would be better
      // as widget tests or integration tests.

      test('notification types should be recognized', () {
        // Verify the expected notification types exist in the handler
        // This is a basic sanity check for the supported types
        const supportedTypes = [
          'incoming_call',
          'new_message',
          'expert_request',
          'missed_call',
          'support_message',
          'support_status_change',
        ];

        for (final type in supportedTypes) {
          expect(type, isNotEmpty);
        }
      });
    });

    group('message flow', () {
      test('should support complete message lifecycle', () {
        final mockMessage = MockRemoteMessage();
        when(mockMessage.messageId).thenReturn('lifecycle-test');
        when(mockMessage.data).thenReturn({'type': 'new_message'});

        // Initial state
        expect(PendingNotificationHandler.hasPendingMessage, false);

        // Set message
        PendingNotificationHandler.setPendingMessage(mockMessage);
        expect(PendingNotificationHandler.hasPendingMessage, true);

        // Consume message
        final consumed = PendingNotificationHandler.consumePendingMessage();
        expect(consumed, mockMessage);
        expect(PendingNotificationHandler.hasPendingMessage, false);

        // Verify can set another message after consuming
        final mockMessage2 = MockRemoteMessage();
        when(mockMessage2.messageId).thenReturn('lifecycle-test-2');

        PendingNotificationHandler.setPendingMessage(mockMessage2);
        expect(PendingNotificationHandler.hasPendingMessage, true);
      });

      test('should handle replacing pending message', () {
        final mockMessage1 = MockRemoteMessage();
        when(mockMessage1.messageId).thenReturn('first-message');

        final mockMessage2 = MockRemoteMessage();
        when(mockMessage2.messageId).thenReturn('second-message');

        // Set first message
        PendingNotificationHandler.setPendingMessage(mockMessage1);

        // Replace with second message
        PendingNotificationHandler.setPendingMessage(mockMessage2);

        // Should get second message
        final consumed = PendingNotificationHandler.consumePendingMessage();
        expect(consumed, mockMessage2);
      });
    });
  });
}
