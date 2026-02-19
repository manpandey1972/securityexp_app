import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';

void main() {
  group('SupportMessage', () {
    group('fromJson', () {
      test('should create SupportMessage from valid JSON', () {
        final json = {
          'id': 'msg-123',
          'ticketId': 'ticket-456',
          'senderType': 'user',
          'senderId': 'user-789',
          'senderName': 'John Doe',
          'content': 'Hello, I need help',
          'createdAt': '2026-01-28T10:00:00.000Z',
          'readAt': null,
          'attachments': [],
        };

        final message = SupportMessage.fromJson(json);

        expect(message.id, 'msg-123');
        expect(message.ticketId, 'ticket-456');
        expect(message.senderType, MessageSenderType.user);
        expect(message.senderId, 'user-789');
        expect(message.senderName, 'John Doe');
        expect(message.content, 'Hello, I need help');
        expect(message.readAt, isNull);
        expect(message.attachments, isEmpty);
      });

      test('should parse support message type', () {
        final json = {
          'id': 'msg-123',
          'ticketId': 'ticket-456',
          'senderType': 'support',
          'senderId': 'support-agent-1',
          'senderName': 'Support Agent',
          'content': 'How can I help?',
          'createdAt': '2026-01-28T10:00:00.000Z',
        };

        final message = SupportMessage.fromJson(json);

        expect(message.senderType, MessageSenderType.support);
      });

      test('should parse system message type', () {
        final json = {
          'id': 'msg-123',
          'ticketId': 'ticket-456',
          'senderType': 'system',
          'senderId': 'system',
          'senderName': 'System',
          'content': 'Ticket created',
          'systemMessageType': 'ticket_created',
          'createdAt': '2026-01-28T10:00:00.000Z',
        };

        final message = SupportMessage.fromJson(json);

        expect(message.senderType, MessageSenderType.system);
        expect(message.systemMessageType, SystemMessageType.ticketCreated);
      });

      test('should handle attachments', () {
        final json = {
          'id': 'msg-123',
          'ticketId': 'ticket-456',
          'senderType': 'user',
          'content': 'See attached',
          'createdAt': '2026-01-28T10:00:00.000Z',
          'attachments': [
            {
              'id': 'att-1',
              'url': 'https://example.com/image.png',
              'fileName': 'image.png',
              'fileSize': 1024,
              'mimeType': 'image/png',
              'uploadedAt': '2026-01-28T10:00:00.000Z',
            },
          ],
        };

        final message = SupportMessage.fromJson(json);

        expect(message.attachments.length, 1);
        expect(message.attachments.first.fileName, 'image.png');
        expect(message.attachments.first.mimeType, 'image/png');
      });
    });

    group('toJson', () {
      test('should convert SupportMessage to JSON', () {
        final message = SupportMessage(
          id: 'msg-123',
          ticketId: 'ticket-456',
          senderType: MessageSenderType.user,
          senderId: 'user-789',
          senderName: 'John Doe',
          content: 'Hello',
          createdAt: DateTime(2026, 1, 28, 10, 0, 0),
        );

        final json = message.toJson();

        expect(json['id'], 'msg-123');
        expect(json['ticketId'], 'ticket-456');
        expect(json['senderType'], 'user');
        expect(json['senderId'], 'user-789');
        expect(json['senderName'], 'John Doe');
        expect(json['content'], 'Hello');
      });
    });

    group('computed properties', () {
      test('isSystemMessage returns true for system messages', () {
        final message = _createMessage(senderType: MessageSenderType.system);
        expect(message.isSystemMessage, true);
      });

      test('isSystemMessage returns false for user messages', () {
        final message = _createMessage(senderType: MessageSenderType.user);
        expect(message.isSystemMessage, false);
      });

      test('isFromSupport returns true for support messages', () {
        final message = _createMessage(senderType: MessageSenderType.support);
        expect(message.isFromSupport, true);
      });

      test('isFromSupport returns false for user messages', () {
        final message = _createMessage(senderType: MessageSenderType.user);
        expect(message.isFromSupport, false);
      });

      test('isFromUser returns true for user messages', () {
        final message = _createMessage(senderType: MessageSenderType.user);
        expect(message.isFromUser, true);
      });

      test('isFromUser returns false for support messages', () {
        final message = _createMessage(senderType: MessageSenderType.support);
        expect(message.isFromUser, false);
      });

      test('isRead returns true when readAt is set', () {
        final message = SupportMessage(
          id: 'msg-123',
          ticketId: 'ticket-456',
          senderId: 'agent-1',
          senderType: MessageSenderType.support,
          senderName: 'Support Agent',
          content: 'Hello',
          createdAt: DateTime.now(),
          readAt: DateTime.now(),
        );
        expect(message.isRead, true);
      });

      test('isRead returns false when readAt is null', () {
        final message = SupportMessage(
          id: 'msg-123',
          ticketId: 'ticket-456',
          senderId: 'agent-1',
          senderType: MessageSenderType.support,
          senderName: 'Support Agent',
          content: 'Hello',
          createdAt: DateTime.now(),
          readAt: null,
        );
        expect(message.isRead, false);
      });
    });
  });

  group('MessageSenderType', () {
    test('fromJson creates correct type', () {
      expect(MessageSenderType.fromJson('user'), MessageSenderType.user);
      expect(MessageSenderType.fromJson('support'), MessageSenderType.support);
      expect(MessageSenderType.fromJson('system'), MessageSenderType.system);
    });

    test('toJson returns correct string', () {
      expect(MessageSenderType.user.toJson(), 'user');
      expect(MessageSenderType.support.toJson(), 'support');
      expect(MessageSenderType.system.toJson(), 'system');
    });
  });

  group('SystemMessageType', () {
    test('fromJson creates correct type', () {
      expect(
        SystemMessageType.fromJson('ticket_created'),
        SystemMessageType.ticketCreated,
      );
      expect(
        SystemMessageType.fromJson('status_change'),
        SystemMessageType.statusChange,
      );
      expect(
        SystemMessageType.fromJson('ticket_resolved'),
        SystemMessageType.ticketResolved,
      );
      expect(
        SystemMessageType.fromJson('ticket_closed'),
        SystemMessageType.ticketClosed,
      );
    });

    test('toJson returns correct string', () {
      expect(
        SystemMessageType.ticketCreated.toJson(),
        'ticket_created',
      );
      expect(
        SystemMessageType.statusChange.toJson(),
        'status_change',
      );
      expect(
        SystemMessageType.ticketResolved.toJson(),
        'ticket_resolved',
      );
      expect(
        SystemMessageType.ticketClosed.toJson(),
        'ticket_closed',
      );
    });
  });

  group('TicketAttachment', () {
    test('fromJson creates correct attachment', () {
      final json = {
        'id': 'att-123',
        'url': 'https://example.com/file.pdf',
        'fileName': 'document.pdf',
        'fileSize': 2048,
        'mimeType': 'application/pdf',
        'uploadedAt': '2026-01-28T10:00:00.000Z',
      };

      final attachment = TicketAttachment.fromJson(json);

      expect(attachment.id, 'att-123');
      expect(attachment.url, 'https://example.com/file.pdf');
      expect(attachment.fileName, 'document.pdf');
      expect(attachment.fileSize, 2048);
      expect(attachment.mimeType, 'application/pdf');
    });

    test('toJson returns correct JSON', () {
      final attachment = TicketAttachment(
        id: 'att-123',
        url: 'https://example.com/file.pdf',
        fileName: 'document.pdf',
        fileSize: 2048,
        mimeType: 'application/pdf',
        uploadedAt: DateTime(2026, 1, 28, 10, 0, 0),
      );

      final json = attachment.toJson();

      expect(json['id'], 'att-123');
      expect(json['url'], 'https://example.com/file.pdf');
      expect(json['fileName'], 'document.pdf');
      expect(json['fileSize'], 2048);
      expect(json['mimeType'], 'application/pdf');
    });

    test('isImage returns true for image mime types', () {
      final imageAttachment = TicketAttachment(
        id: 'att-1',
        url: 'https://example.com/image.png',
        fileName: 'image.png',
        fileSize: 1024,
        mimeType: 'image/png',
        uploadedAt: DateTime.now(),
      );

      expect(imageAttachment.isImage, true);
    });

    test('isImage returns false for non-image mime types', () {
      final pdfAttachment = TicketAttachment(
        id: 'att-1',
        url: 'https://example.com/doc.pdf',
        fileName: 'doc.pdf',
        fileSize: 1024,
        mimeType: 'application/pdf',
        uploadedAt: DateTime.now(),
      );

      expect(pdfAttachment.isImage, false);
    });
  });
}

/// Helper to create a test message with specified sender type.
SupportMessage _createMessage({required MessageSenderType senderType}) {
  return SupportMessage(
    id: 'test-id',
    ticketId: 'ticket-123',
    senderId: 'sender-123',
    senderType: senderType,
    senderName: 'Test Sender',
    content: 'Test content',
    createdAt: DateTime.now(),
  );
}
