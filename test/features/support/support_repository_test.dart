import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:greenhive_app/features/support/data/models/models.dart';

/// Unit tests for Support models
///
/// Tests cover model parsing, validation, and edge cases.
/// Integration tests with Firestore require additional setup.
void main() {
  group('TicketType Enum', () {
    test('should have all expected values', () {
      expect(TicketType.values, contains(TicketType.bug));
      expect(TicketType.values, contains(TicketType.featureRequest));
      expect(TicketType.values, contains(TicketType.feedback));
      expect(TicketType.values, contains(TicketType.support));
      expect(TicketType.values, contains(TicketType.payment));
      expect(TicketType.values, contains(TicketType.account));
    });

    test('fromJson should parse valid strings', () {
      expect(TicketType.fromJson('bug'), equals(TicketType.bug));
      expect(TicketType.fromJson('featureRequest'), equals(TicketType.featureRequest));
      expect(TicketType.fromJson('support'), equals(TicketType.support));
    });

    test('fromJson should return default for invalid strings', () {
      expect(TicketType.fromJson('invalid'), equals(TicketType.support));
    });

    test('displayName should return human-readable names', () {
      expect(TicketType.bug.displayName, equals('Bug Report'));
      expect(TicketType.featureRequest.displayName, equals('Feature Request'));
      expect(TicketType.payment.displayName, equals('Payment Issue'));
    });

    test('toJson should serialize correctly', () {
      expect(TicketType.bug.toJson(), equals('bug'));
      expect(TicketType.featureRequest.toJson(), equals('featureRequest'));
    });

    test('emoji should return appropriate icons', () {
      expect(TicketType.bug.emoji, equals('🐛'));
      expect(TicketType.featureRequest.emoji, equals('💡'));
      expect(TicketType.payment.emoji, equals('💳'));
    });

    test('description should return helpful text', () {
      expect(TicketType.bug.description, contains('crashes'));
      expect(TicketType.featureRequest.description, contains('features'));
    });
  });

  group('TicketStatus Enum', () {
    test('should have all expected values', () {
      expect(TicketStatus.values, contains(TicketStatus.open));
      expect(TicketStatus.values, contains(TicketStatus.inProgress));
      expect(TicketStatus.values, contains(TicketStatus.inReview));
      expect(TicketStatus.values, contains(TicketStatus.resolved));
      expect(TicketStatus.values, contains(TicketStatus.closed));
    });

    test('displayName should return human-readable names', () {
      expect(TicketStatus.open.displayName, equals('Open'));
      expect(TicketStatus.inProgress.displayName, equals('In Progress'));
      expect(TicketStatus.inReview.displayName, equals('In Review'));
      expect(TicketStatus.resolved.displayName, equals('Resolved'));
      expect(TicketStatus.closed.displayName, equals('Closed'));
    });

    test('toJson should serialize with underscores for multi-word statuses', () {
      expect(TicketStatus.open.toJson(), equals('open'));
      expect(TicketStatus.inReview.toJson(), equals('in_review'));
      expect(TicketStatus.inProgress.toJson(), equals('in_progress'));
    });

    test('fromJson should parse with underscores', () {
      expect(TicketStatus.fromJson('open'), equals(TicketStatus.open));
      expect(TicketStatus.fromJson('in_review'), equals(TicketStatus.inReview));
      expect(TicketStatus.fromJson('in_progress'), equals(TicketStatus.inProgress));
    });

    test('fromJson should return default for invalid strings', () {
      expect(TicketStatus.fromJson('invalid'), equals(TicketStatus.open));
    });
  });

  group('TicketPriority Enum', () {
    test('should have all expected values', () {
      expect(TicketPriority.values, contains(TicketPriority.low));
      expect(TicketPriority.values, contains(TicketPriority.medium));
      expect(TicketPriority.values, contains(TicketPriority.high));
      expect(TicketPriority.values, contains(TicketPriority.critical));
    });

    test('fromTicketType should assign critical priority for payment', () {
      expect(
        TicketPriority.fromTicketType(TicketType.payment),
        equals(TicketPriority.critical),
      );
    });

    test('fromTicketType should assign high priority for bugs', () {
      expect(
        TicketPriority.fromTicketType(TicketType.bug),
        equals(TicketPriority.high),
      );
    });

    test('fromTicketType should assign high priority for account issues', () {
      expect(
        TicketPriority.fromTicketType(TicketType.account),
        equals(TicketPriority.high),
      );
    });

    test('fromTicketType should assign medium priority for support', () {
      expect(
        TicketPriority.fromTicketType(TicketType.support),
        equals(TicketPriority.medium),
      );
    });

    test('fromTicketType should assign low priority for feature requests', () {
      expect(
        TicketPriority.fromTicketType(TicketType.featureRequest),
        equals(TicketPriority.low),
      );
    });

    test('fromTicketType should assign low priority for feedback', () {
      expect(
        TicketPriority.fromTicketType(TicketType.feedback),
        equals(TicketPriority.low),
      );
    });

    test('displayName should return human-readable names', () {
      expect(TicketPriority.low.displayName, equals('Low'));
      expect(TicketPriority.medium.displayName, equals('Medium'));
      expect(TicketPriority.high.displayName, equals('High'));
      expect(TicketPriority.critical.displayName, equals('Critical'));
    });

    test('toJson should serialize correctly', () {
      expect(TicketPriority.low.toJson(), equals('low'));
      expect(TicketPriority.critical.toJson(), equals('critical'));
    });

    test('fromJson should parse valid strings', () {
      expect(TicketPriority.fromJson('low'), equals(TicketPriority.low));
      expect(TicketPriority.fromJson('critical'), equals(TicketPriority.critical));
    });

    test('fromJson should return default for invalid strings', () {
      expect(TicketPriority.fromJson('invalid'), equals(TicketPriority.medium));
    });
  });

  group('TicketCategory Enum', () {
    test('should have all expected values', () {
      expect(TicketCategory.values, contains(TicketCategory.calling));
      expect(TicketCategory.values, contains(TicketCategory.chat));
      expect(TicketCategory.values, contains(TicketCategory.profile));
      expect(TicketCategory.values, contains(TicketCategory.notifications));
      expect(TicketCategory.values, contains(TicketCategory.experts));
      expect(TicketCategory.values, contains(TicketCategory.performance));
      expect(TicketCategory.values, contains(TicketCategory.other));
    });

    test('displayName should return human-readable names', () {
      expect(TicketCategory.calling.displayName, equals('Calling & Video'));
      expect(TicketCategory.chat.displayName, equals('Chat & Messaging'));
      expect(TicketCategory.profile.displayName, equals('Profile & Settings'));
      expect(TicketCategory.other.displayName, equals('Other'));
    });

    test('toJson should serialize correctly', () {
      expect(TicketCategory.calling.toJson(), equals('calling'));
      expect(TicketCategory.performance.toJson(), equals('performance'));
    });

    test('fromJson should parse valid strings', () {
      expect(TicketCategory.fromJson('calling'), equals(TicketCategory.calling));
      expect(TicketCategory.fromJson('chat'), equals(TicketCategory.chat));
    });

    test('fromJson should return default for invalid strings', () {
      expect(TicketCategory.fromJson('invalid'), equals(TicketCategory.other));
    });
  });

  group('MessageSenderType Enum', () {
    test('should have all expected values', () {
      expect(MessageSenderType.values, contains(MessageSenderType.user));
      expect(MessageSenderType.values, contains(MessageSenderType.support));
      expect(MessageSenderType.values, contains(MessageSenderType.system));
    });

    test('toJson should serialize correctly', () {
      expect(MessageSenderType.user.toJson(), equals('user'));
      expect(MessageSenderType.support.toJson(), equals('support'));
      expect(MessageSenderType.system.toJson(), equals('system'));
    });

    test('fromJson should parse valid strings', () {
      expect(MessageSenderType.fromJson('user'), equals(MessageSenderType.user));
      expect(MessageSenderType.fromJson('support'), equals(MessageSenderType.support));
    });

    test('fromJson should return default for invalid strings', () {
      expect(MessageSenderType.fromJson('invalid'), equals(MessageSenderType.user));
    });
  });

  group('SystemMessageType Enum', () {
    test('should have all expected values', () {
      expect(SystemMessageType.values, contains(SystemMessageType.statusChange));
      expect(SystemMessageType.values, contains(SystemMessageType.assignmentChange));
      expect(SystemMessageType.values, contains(SystemMessageType.ticketCreated));
      expect(SystemMessageType.values, contains(SystemMessageType.ticketResolved));
      expect(SystemMessageType.values, contains(SystemMessageType.ticketClosed));
    });

    test('toJson should serialize with underscores', () {
      expect(SystemMessageType.statusChange.toJson(), equals('status_change'));
      expect(SystemMessageType.ticketCreated.toJson(), equals('ticket_created'));
    });

    test('fromJson should parse with underscores', () {
      expect(
        SystemMessageType.fromJson('status_change'),
        equals(SystemMessageType.statusChange),
      );
      expect(
        SystemMessageType.fromJson('ticket_created'),
        equals(SystemMessageType.ticketCreated),
      );
    });

    test('fromJson should return null for null input', () {
      expect(SystemMessageType.fromJson(null), isNull);
    });

    test('fromJson should return null for invalid strings', () {
      expect(SystemMessageType.fromJson('invalid'), isNull);
    });
  });

  group('ResolutionType Enum', () {
    test('should have all expected values', () {
      expect(ResolutionType.values, contains(ResolutionType.fixed));
      expect(ResolutionType.values, contains(ResolutionType.duplicate));
      expect(ResolutionType.values, contains(ResolutionType.wontFix));
      expect(ResolutionType.values, contains(ResolutionType.invalid));
      expect(ResolutionType.values, contains(ResolutionType.userResolved));
    });

    test('displayName should return human-readable names', () {
      expect(ResolutionType.fixed.displayName, equals('Fixed'));
      expect(ResolutionType.wontFix.displayName, equals("Won't Fix"));
      expect(ResolutionType.userResolved.displayName, equals('Resolved by User'));
    });

    test('toJson should serialize with underscores', () {
      expect(ResolutionType.fixed.toJson(), equals('fixed'));
      expect(ResolutionType.wontFix.toJson(), equals('wont_fix'));
      expect(ResolutionType.userResolved.toJson(), equals('user_resolved'));
    });

    test('fromJson should parse with underscores', () {
      expect(ResolutionType.fromJson('wont_fix'), equals(ResolutionType.wontFix));
      expect(
        ResolutionType.fromJson('user_resolved'),
        equals(ResolutionType.userResolved),
      );
    });

    test('fromJson should return null for null input', () {
      expect(ResolutionType.fromJson(null), isNull);
    });
  });

  group('PendingAttachment Model', () {
    test('should create from bytes', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final attachment = PendingAttachment.fromBytes(
        bytes,
        'test_image.png',
      );

      expect(attachment.bytes, equals(bytes));
      expect(attachment.filename, equals('test_image.png'));
      expect(attachment.filePath, isNull);
    });

    test('should create from path', () {
      final attachment = PendingAttachment.fromPath(
        '/path/to/file.pdf',
        'document.pdf',
      );

      expect(attachment.filePath, equals('/path/to/file.pdf'));
      expect(attachment.filename, equals('document.pdf'));
      expect(attachment.bytes, isNull);
    });

    test('should store filename correctly for images', () {
      final attachment = PendingAttachment.fromBytes(
        Uint8List.fromList([0, 1, 2]),
        'photo.jpg',
      );

      expect(attachment.filename, equals('photo.jpg'));
      expect(attachment.filename.toLowerCase().endsWith('.jpg'), isTrue);
    });

    test('should store filename correctly for PDFs', () {
      final attachment = PendingAttachment.fromBytes(
        Uint8List.fromList([0, 1, 2]),
        'document.pdf',
      );

      expect(attachment.filename, equals('document.pdf'));
      expect(attachment.filename.toLowerCase().endsWith('.pdf'), isTrue);
    });

    test('should distinguish image files by extension', () {
      final imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
      for (final ext in imageExtensions) {
        final attachment = PendingAttachment.fromBytes(
          Uint8List.fromList([0]),
          'photo.$ext',
        );
        expect(attachment.filename.endsWith(ext), isTrue);
      }
    });
  });

  group('DeviceContext Model', () {
    test('should parse from JSON', () {
      final json = {
        'platform': 'iOS',
        'osVersion': '17.0',
        'appVersion': '1.2.3',
        'buildNumber': '42',
        'deviceModel': 'iPhone 15 Pro',
        'locale': 'en_US',
        'timezone': 'America/New_York',
        'screenSize': '393x852',
      };

      final context = DeviceContext.fromJson(json);

      expect(context.platform, equals('iOS'));
      expect(context.osVersion, equals('17.0'));
      expect(context.appVersion, equals('1.2.3'));
      expect(context.buildNumber, equals('42'));
      expect(context.deviceModel, equals('iPhone 15 Pro'));
      expect(context.locale, equals('en_US'));
      expect(context.timezone, equals('America/New_York'));
    });

    test('should handle missing optional fields', () {
      final json = {
        'platform': 'Android',
        'osVersion': '14',
        'appVersion': '1.0.0',
        'buildNumber': '1',
        'locale': 'en_US',
        'timezone': 'UTC',
      };

      final context = DeviceContext.fromJson(json);

      expect(context.platform, equals('Android'));
      expect(context.deviceModel, isNull);
      expect(context.screenSize, isNull);
    });

    test('should serialize to JSON', () {
      const context = DeviceContext(
        platform: 'iOS',
        osVersion: '17.0',
        appVersion: '1.2.3',
        buildNumber: '42',
        deviceModel: 'iPhone 15',
        locale: 'en_US',
        timezone: 'UTC',
      );

      final json = context.toJson();

      expect(json['platform'], equals('iOS'));
      expect(json['osVersion'], equals('17.0'));
      expect(json['appVersion'], equals('1.2.3'));
      expect(json['buildNumber'], equals('42'));
    });
  });

  group('SupportMessage Model', () {
    test('should parse message from JSON', () {
      final json = {
        'ticketId': 'ticket-456',
        'senderId': 'user-789',
        'senderName': 'Test User',
        'senderType': 'user',
        'content': 'Hello, I need help',
        'attachments': <dynamic>[],
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isInternal': false,
      };

      final message = SupportMessage.fromJson(json, docId: 'msg-123');

      expect(message.id, equals('msg-123'));
      expect(message.ticketId, equals('ticket-456'));
      expect(message.senderId, equals('user-789'));
      expect(message.content, equals('Hello, I need help'));
      expect(message.senderType, equals(MessageSenderType.user));
      expect(message.isInternal, isFalse);
    });

    test('should handle support sender type', () {
      final json = {
        'ticketId': 'ticket-456',
        'senderId': 'agent-001',
        'senderName': 'Support Agent',
        'senderType': 'support',
        'content': 'How can I help?',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isInternal': false,
      };

      final message = SupportMessage.fromJson(json, docId: 'msg-123');

      expect(message.senderType, equals(MessageSenderType.support));
      expect(message.isFromSupport, isTrue);
      expect(message.isFromUser, isFalse);
    });

    test('should handle system messages', () {
      final json = {
        'ticketId': 'ticket-456',
        'senderId': 'system',
        'senderName': 'System',
        'senderType': 'system',
        'content': 'Ticket status changed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isInternal': false,
        'systemMessageType': 'status_change',
      };

      final message = SupportMessage.fromJson(json, docId: 'msg-123');

      expect(message.senderType, equals(MessageSenderType.system));
      expect(message.isSystemMessage, isTrue);
      expect(message.systemMessageType, equals(SystemMessageType.statusChange));
    });

    test('should handle internal messages', () {
      final json = {
        'ticketId': 'ticket-456',
        'senderId': 'agent-001',
        'senderName': 'Support Agent',
        'senderType': 'support',
        'content': 'Internal note',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isInternal': true,
      };

      final message = SupportMessage.fromJson(json, docId: 'msg-123');

      expect(message.isInternal, isTrue);
    });

    test('computed properties should work correctly', () {
      final readMessage = SupportMessage(
        id: 'msg-1',
        ticketId: 'ticket-1',
        senderId: 'user-1',
        senderType: MessageSenderType.user,
        senderName: 'Test',
        content: 'Test message',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        readAt: DateTime.now(),
      );

      final unreadMessage = SupportMessage(
        id: 'msg-2',
        ticketId: 'ticket-1',
        senderId: 'user-1',
        senderType: MessageSenderType.user,
        senderName: 'Test',
        content: 'Test message',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(readMessage.isRead, isTrue);
      expect(unreadMessage.isRead, isFalse);
    });

    test('hasAttachments should return correct value', () {
      final withAttachments = SupportMessage(
        id: 'msg-1',
        ticketId: 'ticket-1',
        senderId: 'user-1',
        senderType: MessageSenderType.user,
        senderName: 'Test',
        content: 'Test message',
        createdAt: DateTime.now(),
        attachments: [
          TicketAttachment(
            id: 'att-1',
            fileName: 'test.png',
            mimeType: 'image/png',
            fileSize: 1024,
            url: 'https://example.com/test.png',
            uploadedAt: DateTime.now(),
          ),
        ],
      );

      final withoutAttachments = SupportMessage(
        id: 'msg-2',
        ticketId: 'ticket-1',
        senderId: 'user-1',
        senderType: MessageSenderType.user,
        senderName: 'Test',
        content: 'Test message',
        createdAt: DateTime.now(),
      );

      expect(withAttachments.hasAttachments, isTrue);
      expect(withoutAttachments.hasAttachments, isFalse);
    });
  });

  group('SupportTicket Model', () {
    late DeviceContext deviceContext;

    setUp(() {
      deviceContext = const DeviceContext(
        platform: 'iOS',
        osVersion: '17.0',
        appVersion: '1.0.0',
        buildNumber: '1',
        locale: 'en_US',
        timezone: 'UTC',
      );
    });

    test('should parse complete ticket from JSON', () {
      final json = {
        'ticketNumber': 'GH-2026-00001',
        'userId': 'user-456',
        'userEmail': 'user@example.com',
        'userName': 'Test User',
        'type': 'bug',
        'category': 'performance',
        'subject': 'App crashes',
        'description': 'App crashes on launch',
        'attachments': <dynamic>[],
        'deviceContext': {
          'platform': 'iOS',
          'osVersion': '17.0',
          'appVersion': '1.0.0',
          'buildNumber': '1',
          'deviceModel': 'iPhone 15',
          'locale': 'en_US',
          'timezone': 'UTC',
        },
        'status': 'open',
        'priority': 'high',
        'tags': ['crash', 'ios'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'lastActivityAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'messageCount': 0,
        'hasUnreadSupportMessages': false,
        'isAutoCreated': false,
      };

      final ticket = SupportTicket.fromJson(json, docId: 'ticket-123');

      expect(ticket.id, equals('ticket-123'));
      expect(ticket.ticketNumber, equals('GH-2026-00001'));
      expect(ticket.userId, equals('user-456'));
      expect(ticket.userEmail, equals('user@example.com'));
      expect(ticket.type, equals(TicketType.bug));
      expect(ticket.category, equals(TicketCategory.performance));
      expect(ticket.status, equals(TicketStatus.open));
      expect(ticket.priority, equals(TicketPriority.high));
      expect(ticket.tags, contains('crash'));
    });

    test('isOpen should return true for active statuses', () {
      final openTicket = SupportTicket(
        id: 'ticket-1',
        ticketNumber: 'GH-001',
        userEmail: 'test@example.com',
        type: TicketType.bug,
        category: TicketCategory.performance,
        subject: 'Test',
        description: 'Test',
        deviceContext: deviceContext,
        status: TicketStatus.open,
        priority: TicketPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      final inProgressTicket = openTicket.copyWith(status: TicketStatus.inProgress);
      final inReviewTicket = openTicket.copyWith(status: TicketStatus.inReview);
      final resolvedTicket = openTicket.copyWith(status: TicketStatus.resolved);
      final closedTicket = openTicket.copyWith(status: TicketStatus.closed);

      expect(openTicket.isOpen, isTrue);
      expect(inProgressTicket.isOpen, isTrue);
      expect(inReviewTicket.isOpen, isTrue);
      expect(resolvedTicket.isOpen, isFalse);
      expect(closedTicket.isOpen, isFalse);
    });

    test('canReply should return false only for closed tickets', () {
      final openTicket = SupportTicket(
        id: 'ticket-1',
        ticketNumber: 'GH-001',
        userEmail: 'test@example.com',
        type: TicketType.bug,
        category: TicketCategory.performance,
        subject: 'Test',
        description: 'Test',
        deviceContext: deviceContext,
        status: TicketStatus.open,
        priority: TicketPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      final resolvedTicket = openTicket.copyWith(status: TicketStatus.resolved);
      final closedTicket = openTicket.copyWith(status: TicketStatus.closed);

      expect(openTicket.canReply, isTrue);
      expect(resolvedTicket.canReply, isTrue);
      expect(closedTicket.canReply, isFalse);
    });

    test('copyWith should create copy with updated fields', () {
      final original = SupportTicket(
        id: 'ticket-123',
        ticketNumber: 'GH-001',
        userId: 'user-456',
        userEmail: 'user@example.com',
        type: TicketType.bug,
        category: TicketCategory.performance,
        subject: 'Original',
        description: 'Original desc',
        deviceContext: deviceContext,
        status: TicketStatus.open,
        priority: TicketPriority.medium,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        lastActivityAt: DateTime(2026, 1, 15),
      );

      final updated = original.copyWith(
        status: TicketStatus.inProgress,
        priority: TicketPriority.high,
        assignedTo: 'agent-789',
      );

      expect(updated.id, equals('ticket-123'));
      expect(updated.status, equals(TicketStatus.inProgress));
      expect(updated.priority, equals(TicketPriority.high));
      expect(updated.assignedTo, equals('agent-789'));
      expect(original.status, equals(TicketStatus.open)); // Original unchanged
    });

    test('toJson should convert ticket to JSON', () {
      final ticket = SupportTicket(
        id: 'ticket-123',
        ticketNumber: 'GH-2026-00001',
        userId: 'user-456',
        userEmail: 'user@example.com',
        type: TicketType.bug,
        category: TicketCategory.performance,
        subject: 'App crashes',
        description: 'Details here',
        deviceContext: deviceContext,
        status: TicketStatus.open,
        priority: TicketPriority.high,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        lastActivityAt: DateTime(2026, 1, 15),
      );

      final json = ticket.toJson();

      expect(json['userId'], equals('user-456'));
      expect(json['userEmail'], equals('user@example.com'));
      expect(json['type'], equals('bug'));
      expect(json['category'], equals('performance'));
      expect(json['status'], equals('open'));
      expect(json['priority'], equals('high'));
    });
  });

  group('TicketAttachment Model', () {
    test('should parse from JSON', () {
      final json = {
        'id': 'att-123',
        'fileName': 'screenshot.png',
        'mimeType': 'image/png',
        'fileSize': 1024,
        'url': 'https://storage.example.com/screenshot.png',
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
      };

      final attachment = TicketAttachment.fromJson(json);

      expect(attachment.id, equals('att-123'));
      expect(attachment.fileName, equals('screenshot.png'));
      expect(attachment.mimeType, equals('image/png'));
      expect(attachment.fileSize, equals(1024));
    });

    test('isImage should return true for image content types', () {
      final imageAttachment = TicketAttachment(
        id: 'att-1',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024,
        url: 'https://example.com/photo.jpg',
        uploadedAt: DateTime.now(),
      );

      final pdfAttachment = TicketAttachment(
        id: 'att-2',
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        fileSize: 2048,
        url: 'https://example.com/doc.pdf',
        uploadedAt: DateTime.now(),
      );

      expect(imageAttachment.isImage, isTrue);
      expect(pdfAttachment.isImage, isFalse);
    });

    test('fileSizeFormatted should return human-readable size', () {
      final smallAttachment = TicketAttachment(
        id: 'att-1',
        fileName: 'small.txt',
        mimeType: 'text/plain',
        fileSize: 500, // 500 bytes
        url: 'https://example.com/small.txt',
        uploadedAt: DateTime.now(),
      );

      final mediumAttachment = TicketAttachment(
        id: 'att-2',
        fileName: 'medium.pdf',
        mimeType: 'application/pdf',
        fileSize: 1536, // 1.5 KB
        url: 'https://example.com/medium.pdf',
        uploadedAt: DateTime.now(),
      );

      expect(smallAttachment.fileSizeFormatted, contains('B'));
      expect(mediumAttachment.fileSizeFormatted, contains('KB'));
    });

    test('isPdf should return true for PDF files', () {
      final pdfAttachment = TicketAttachment(
        id: 'att-1',
        fileName: 'document.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024,
        url: 'https://example.com/document.pdf',
        uploadedAt: DateTime.now(),
      );

      final imageAttachment = TicketAttachment(
        id: 'att-2',
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileSize: 1024,
        url: 'https://example.com/photo.png',
        uploadedAt: DateTime.now(),
      );

      expect(pdfAttachment.isPdf, isTrue);
      expect(imageAttachment.isPdf, isFalse);
    });
  });
}
