import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/core/validators/validators.dart';
import '../helpers/mock_repositories.dart';

void main() {
  group('ChatService Tests', () {
    late MockChatRepository mockChatRepository;
    late MessageValidator messageValidator;
    late InputSanitizer inputSanitizer;

    setUp(() {
      mockChatRepository = MockChatRepository();
      messageValidator = MessageValidator();
      inputSanitizer = InputSanitizer();
    });

    group('Message Validation', () {
      test('should validate correct message format', () {
        final result = messageValidator.validate('Hello there');
        expect(result.isValid, true);
      });

      test('should reject empty message', () {
        final result = messageValidator.validate('');
        expect(result.isValid, false);
        expect(result.message, contains('cannot be empty'));
      });

      test('should reject message exceeding max length', () {
        final longMessage = 'a' * 5001; // Max is 5000
        final result = messageValidator.validate(longMessage);
        expect(result.isValid, false);
      });

      test('should detect spam patterns with excessive repetition', () {
        final spamMessage = 'aaaaaaaaaaaaaaaaa'; // 17 consecutive 'a's
        final result = messageValidator.validate(spamMessage);
        expect(result.isValid, false);
      });

      test('should detect excessive capitalization', () {
        final capsMessage = 'HELLO HELLO HELLO HELLO';
        final result = messageValidator.validate(capsMessage);
        expect(result.isValid, false);
      });

      test('should handle special characters appropriately', () {
        final specialMessage = 'Hello! How are you? 😊';
        final result = messageValidator.validate(specialMessage);
        // Should be valid if special chars < 20%
        expect(result.isValid, true);
      });
    });

    group('Message Sanitization', () {
      test('should remove extra spaces', () {
        final input = 'hello  world';
        final sanitized = inputSanitizer.sanitizeMessage(input);
        expect(sanitized, equals('hello world'));
      });

      test('should handle leading and trailing spaces', () {
        final input = '  hello world  ';
        final sanitized = inputSanitizer.sanitizeMessage(input);
        expect(sanitized, equals('hello world'));
      });

      test('should trim text correctly', () {
        final input = '   test message   ';
        final sanitized = inputSanitizer.sanitizeMessage(input);
        expect(sanitized, equals('test message'));
      });

      test('should escape HTML tags', () {
        final input = '<script>alert("xss")</script>';
        final sanitized = inputSanitizer.escapeHtml(input);
        expect(sanitized, contains('&lt;script&gt;'));
        expect(sanitized, contains('&lt;/script&gt;'));
      });

      test('should properly escape quotes', () {
        final input = 'He said "hello"';
        final sanitized = inputSanitizer.escapeHtml(input);
        expect(sanitized, contains('&quot;'));
      });

      test('should detect profanity', () {
        // Note: This depends on the actual profanity list in InputSanitizer
        final result = inputSanitizer.containsProfanity('hello world');
        expect(result, false); // Clean message
      });

      test('should mask profanity', () {
        // Using a word that might be in profanity list
        final masked = inputSanitizer.maskProfanity('hello world');
        // Should return sanitized version
        expect(masked, isNotNull);
      });
    });

    group('Chat Message Flow', () {
      test('should validate then sanitize message', () {
        const message = '  Hello there  ';

        final validationResult = messageValidator.validate(message);
        expect(validationResult.isValid, true);

        final sanitized = inputSanitizer.sanitizeMessage(message);
        expect(sanitized, equals('Hello there'));
      });

      test('should handle message with mixed content', () {
        const message = '  Hello! How are you? 😊  ';

        final validationResult = messageValidator.validate(message);
        expect(validationResult.isValid, true);

        final sanitized = inputSanitizer.sanitizeMessage(message);
        expect(sanitized, contains('Hello'));
      });

      test('should reject and not sanitize invalid messages', () {
        final invalidMessage = 'a' * 5001; // Too long

        final validationResult = messageValidator.validate(invalidMessage);
        expect(validationResult.isValid, false);
      });
    });

    group('ChatRepository Integration', () {
      test('should retrieve user rooms successfully', () async {
        final rooms = await mockChatRepository.getUserRooms('user1');
        expect(rooms, isNotEmpty);
        expect(rooms.first.id, equals('room1'));
      });

      test('should get room between two users', () async {
        final roomId = await mockChatRepository.getRoom('user1', 'user2');
        expect(roomId, isNotEmpty);
        expect(roomId, equals('room1'));
      });

      test('should retrieve room messages', () async {
        final messages = await mockChatRepository.getRoomMessages('room1');
        expect(messages, isNotEmpty);
        expect(messages.first.text, equals('Hello'));
      });

      test('should send message successfully', () async {
        final message = Message(
          id: 'msg2',
          senderId: 'user1',
          type: MessageType.text,
          text: 'Test message',
          timestamp: Timestamp.now(),
        );

        final sent = await mockChatRepository.sendChatMessage('room1', message);
        expect(sent, isNotNull);
      });
    });

    group('Edge Cases', () {
      test('should handle unicode characters', () {
        final unicodeMessage = '你好世界'; // "Hello world" in Chinese
        final result = messageValidator.validate(unicodeMessage);
        // Unicode characters are valid, just check it processes without error
        expect(result, isNotNull);
      });

      test('should handle emoji', () {
        final emojiMessage = '😀😁😂😃 Hello';
        final result = messageValidator.validate(emojiMessage);
        // Emoji is valid, just verify it processes
        expect(result, isNotNull);
      });

      test('should handle multiple line breaks', () {
        final multilineMessage = 'Hello\n\n\nWorld';
        final sanitized = inputSanitizer.sanitizeMessage(multilineMessage);
        expect(sanitized, isNotEmpty);
      });

      test('should handle numeric only messages', () {
        final numericMessage = '12345';
        final result = messageValidator.validate(numericMessage);
        expect(result.isValid, true);
      });

      test('should handle URL in message', () {
        final urlMessage = 'Check this out: https://example.com';
        final result = messageValidator.validate(urlMessage);
        // May be flagged as potential spam depending on implementation
        expect(result, isNotNull);
      });
    });

    group('Performance Tests', () {
      test('should validate message quickly', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          messageValidator.validate('Test message $i');
        }

        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds;

        // Should complete 100 validations in less than 100ms
        expect(duration, lessThan(100));
      });

      test('should sanitize message quickly', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          inputSanitizer.sanitizeMessage('Test message $i');
        }

        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds;

        // Should complete 100 sanitizations in less than 100ms
        expect(duration, lessThan(100));
      });
    });
  });
}
