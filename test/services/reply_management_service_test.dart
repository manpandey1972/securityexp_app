import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/chat/services/reply_management_service.dart';
import 'package:greenhive_app/data/models/models.dart';

void main() {
  late ReplyManagementService service;

  setUp(() {
    service = ReplyManagementService();
  });

  group('ReplyManagementService', () {
    test('should initialize without errors', () {
      expect(service, isNotNull);
    });

    group('Reply State Management', () {
      test('should set reply message', () {
        final message = Message(
          id: 'msg1',
          text: 'Test message',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        service.setReplyingTo(message);
        expect(service.replyingTo, equals(message));
      });

      test('should clear reply message', () {
        final message = Message(
          id: 'msg1',
          text: 'Test message',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        service.setReplyingTo(message);
        service.clearReply();
        expect(service.replyingTo, isNull);
      });

      test('should indicate if replying', () {
        expect(service.isReplying, false);

        final message = Message(
          id: 'msg1',
          text: 'Test message',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        service.setReplyingTo(message);
        expect(service.isReplying, true);

        service.clearReply();
        expect(service.isReplying, false);
      });
    });

    group('Reply Message Properties', () {
      test('should preserve message details', () {
        final message = Message(
          id: 'msg123',
          text: 'Original message',
          senderId: 'user456',
          timestamp: Timestamp.now(),
        );

        service.setReplyingTo(message);

        expect(service.replyingTo?.id, 'msg123');
        expect(service.replyingTo?.text, 'Original message');
        expect(service.replyingTo?.senderId, 'user456');
      });

      test('should handle messages with media', () {
        final message = Message(
          id: 'msg1',
          text: 'Image message',
          senderId: 'user1',
          timestamp: Timestamp.now(),
          type: MessageType.image,
          mediaUrl: 'https://example.com/image.jpg',
        );

        service.setReplyingTo(message);
        expect(service.replyingTo?.type, MessageType.image);
        expect(service.replyingTo?.mediaUrl, isNotNull);
      });
    });

    group('Reply Toggle', () {
      test('should toggle reply on and off', () {
        final message = Message(
          id: 'msg1',
          text: 'Test',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        // Toggle on
        service.toggleReply(message);
        expect(service.isReplying, true);
        expect(service.replyingTo?.id, 'msg1');

        // Toggle off (same message)
        service.toggleReply(message);
        expect(service.isReplying, false);
        expect(service.replyingTo, isNull);
      });

      test('should replace previous reply when toggling different message', () {
        final message1 = Message(
          id: 'msg1',
          text: 'First message',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        final message2 = Message(
          id: 'msg2',
          text: 'Second message',
          senderId: 'user2',
          timestamp: Timestamp.now(),
        );

        service.toggleReply(message1);
        expect(service.replyingTo?.id, 'msg1');

        service.toggleReply(message2);
        expect(service.replyingTo?.id, 'msg2');
      });
    });

    group('Reply Callback', () {
      test('should call callback when reply is set', () {
        Message? capturedMessage;
        final serviceWithCallback = ReplyManagementService(
          onReplyChanged: (message) {
            capturedMessage = message;
          },
        );

        final message = Message(
          id: 'msg1',
          text: 'Test',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        serviceWithCallback.setReplyingTo(message);
        expect(capturedMessage, equals(message));
      });

      test('should call callback when reply is cleared', () {
        Message? capturedMessage = Message(
          id: 'initial',
          text: 'Initial',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        final serviceWithCallback = ReplyManagementService(
          onReplyChanged: (message) {
            capturedMessage = message;
          },
        );

        final message = Message(
          id: 'msg1',
          text: 'Test',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        serviceWithCallback.setReplyingTo(message);
        serviceWithCallback.clearReply();
        expect(capturedMessage, isNull);
      });
    });

    group('Multiple Reply Updates', () {
      test('should replace previous reply message', () {
        final message1 = Message(
          id: 'msg1',
          text: 'First message',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        final message2 = Message(
          id: 'msg2',
          text: 'Second message',
          senderId: 'user2',
          timestamp: Timestamp.now(),
        );

        service.setReplyingTo(message1);
        expect(service.replyingTo?.id, 'msg1');

        service.setReplyingTo(message2);
        expect(service.replyingTo?.id, 'msg2');
      });

      test('should handle rapid updates', () {
        for (var i = 0; i < 10; i++) {
          final message = Message(
            id: 'msg$i',
            text: 'Message $i',
            senderId: 'user1',
            timestamp: Timestamp.now(),
          );
          service.setReplyingTo(message);
        }

        expect(service.replyingTo?.id, 'msg9');
      });

      test('should handle null reply', () {
        final message = Message(
          id: 'msg1',
          text: 'Test',
          senderId: 'user1',
          timestamp: Timestamp.now(),
        );

        service.setReplyingTo(message);
        expect(service.isReplying, true);

        service.setReplyingTo(null);
        expect(service.isReplying, false);
        expect(service.replyingTo, isNull);
      });
    });
  });
}
