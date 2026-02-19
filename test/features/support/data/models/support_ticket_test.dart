import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';

void main() {
  group('SupportTicket', () {
    group('fromJson', () {
      test('should create SupportTicket from valid JSON', () {
        final json = {
          'id': 'ticket-123',
          'ticketNumber': 'GH-2026-00001',
          'userId': 'user-456',
          'userEmail': 'test@example.com',
          'userName': 'Test User',
          'type': 'bug',
          'category': 'calling',
          'subject': 'Test subject',
          'description': 'Test description',
          'status': 'open',
          'priority': 'medium',
          'createdAt': '2026-01-28T10:00:00.000Z',
          'updatedAt': '2026-01-28T10:00:00.000Z',
          'lastActivityAt': '2026-01-28T10:00:00.000Z',
          'messageCount': 1,
          'hasUnreadSupportMessages': false,
          'attachments': [],
          'tags': [],
          'deviceContext': {
            'platform': 'ios',
            'osVersion': '17.0',
            'appVersion': '1.0.0',
            'buildNumber': '1',
          },
        };

        final ticket = SupportTicket.fromJson(json);

        expect(ticket.id, 'ticket-123');
        expect(ticket.ticketNumber, 'GH-2026-00001');
        expect(ticket.userId, 'user-456');
        expect(ticket.userEmail, 'test@example.com');
        expect(ticket.userName, 'Test User');
        expect(ticket.type, TicketType.bug);
        expect(ticket.category, TicketCategory.calling);
        expect(ticket.subject, 'Test subject');
        expect(ticket.description, 'Test description');
        expect(ticket.status, TicketStatus.open);
        expect(ticket.priority, TicketPriority.medium);
        expect(ticket.messageCount, 1);
        expect(ticket.hasUnreadSupportMessages, false);
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'ticket-123',
          'ticketNumber': '',
          'userId': 'user-456',
          'userEmail': 'test@example.com',
          'type': 'support',
          'category': 'other',
          'subject': 'Test',
          'description': 'Desc',
          'status': 'open',
          'priority': 'low',
          'createdAt': '2026-01-28T10:00:00.000Z',
          'updatedAt': '2026-01-28T10:00:00.000Z',
          'lastActivityAt': '2026-01-28T10:00:00.000Z',
          'messageCount': 0,
          'hasUnreadSupportMessages': false,
          'deviceContext': {
            'platform': 'android',
          },
        };

        final ticket = SupportTicket.fromJson(json);

        expect(ticket.userName, isNull);
        expect(ticket.attachments, isEmpty);
        expect(ticket.tags, isEmpty);
        expect(ticket.assignedTo, isNull);
        expect(ticket.resolvedAt, isNull);
        expect(ticket.closedAt, isNull);
      });
    });

    group('toJson', () {
      test('should convert SupportTicket to JSON', () {
        final ticket = SupportTicket(
          id: 'ticket-123',
          ticketNumber: 'GH-2026-00001',
          userId: 'user-456',
          userEmail: 'test@example.com',
          userName: 'Test User',
          type: TicketType.bug,
          category: TicketCategory.calling,
          subject: 'Test subject',
          description: 'Test description',
          status: TicketStatus.open,
          priority: TicketPriority.medium,
          createdAt: DateTime(2026, 1, 28, 10, 0, 0),
          updatedAt: DateTime(2026, 1, 28, 10, 0, 0),
          lastActivityAt: DateTime(2026, 1, 28, 10, 0, 0),
          messageCount: 1,
          hasUnreadSupportMessages: false,
          deviceContext: DeviceContext(
            platform: 'ios',
            osVersion: '17.0',
            appVersion: '1.0.0',
            buildNumber: '1',
            locale: 'en_US',
            timezone: 'UTC',
          ),
        );

        final json = ticket.toJson();

        expect(json['id'], 'ticket-123');
        expect(json['ticketNumber'], 'GH-2026-00001');
        expect(json['userId'], 'user-456');
        expect(json['type'], 'bug');
        expect(json['category'], 'calling');
        expect(json['status'], 'open');
        expect(json['priority'], 'medium');
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = SupportTicket(
          id: 'ticket-123',
          ticketNumber: 'GH-2026-00001',
          userId: 'user-456',
          userEmail: 'test@example.com',
          type: TicketType.bug,
          category: TicketCategory.calling,
          subject: 'Original subject',
          description: 'Original description',
          status: TicketStatus.open,
          priority: TicketPriority.medium,
          createdAt: DateTime(2026, 1, 28),
          updatedAt: DateTime(2026, 1, 28),
          lastActivityAt: DateTime(2026, 1, 28),
          messageCount: 1,
          hasUnreadSupportMessages: false,
          deviceContext: DeviceContext(
            platform: 'ios',
            osVersion: '17.0',
            appVersion: '1.0.0',
            buildNumber: '1',
            locale: 'en_US',
            timezone: 'UTC',
          ),
        );

        final updated = original.copyWith(
          status: TicketStatus.resolved,
          subject: 'Updated subject',
        );

        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.status, TicketStatus.resolved);
        expect(updated.subject, 'Updated subject');
        expect(updated.description, original.description);
      });
    });

    group('computed properties', () {
      test('isOpen returns true for open tickets', () {
        final ticket = _createTicket(status: TicketStatus.open);
        expect(ticket.isOpen, true);
      });

      test('isOpen returns true for in_review tickets', () {
        final ticket = _createTicket(status: TicketStatus.inReview);
        expect(ticket.isOpen, true);
      });

      test('isOpen returns true for in_progress tickets', () {
        final ticket = _createTicket(status: TicketStatus.inProgress);
        expect(ticket.isOpen, true);
      });

      test('isOpen returns false for resolved tickets', () {
        final ticket = _createTicket(status: TicketStatus.resolved);
        expect(ticket.isOpen, false);
      });

      test('isOpen returns false for closed tickets', () {
        final ticket = _createTicket(status: TicketStatus.closed);
        expect(ticket.isOpen, false);
      });

      test('canReply returns true for open ticket statuses', () {
        expect(_createTicket(status: TicketStatus.open).canReply, true);
        expect(_createTicket(status: TicketStatus.inReview).canReply, true);
        expect(_createTicket(status: TicketStatus.inProgress).canReply, true);
        expect(_createTicket(status: TicketStatus.resolved).canReply, true);
      });

      test('canReply returns false for closed tickets', () {
        expect(_createTicket(status: TicketStatus.closed).canReply, false);
      });
    });
  });

  group('TicketType', () {
    test('displayName returns correct names', () {
      expect(TicketType.bug.displayName, 'Bug Report');
      expect(TicketType.featureRequest.displayName, 'Feature Request');
      expect(TicketType.feedback.displayName, 'Feedback');
      expect(TicketType.support.displayName, 'Support Request');
      expect(TicketType.account.displayName, 'Account Issue');
      expect(TicketType.payment.displayName, 'Payment Issue');
    });

    test('emoji returns correct emojis', () {
      expect(TicketType.bug.emoji, '🐛');
      expect(TicketType.featureRequest.emoji, '💡');
      expect(TicketType.feedback.emoji, '💬');
      expect(TicketType.support.emoji, '🆘');
      expect(TicketType.account.emoji, '👤');
      expect(TicketType.payment.emoji, '💳');
    });

    test('fromJson creates correct type', () {
      expect(TicketType.fromJson('bug'), TicketType.bug);
      expect(TicketType.fromJson('featureRequest'), TicketType.featureRequest);
      expect(TicketType.fromJson('feedback'), TicketType.feedback);
    });

    test('toJson returns correct string', () {
      expect(TicketType.bug.toJson(), 'bug');
      expect(TicketType.featureRequest.toJson(), 'featureRequest');
      expect(TicketType.feedback.toJson(), 'feedback');
    });
  });

  group('TicketStatus', () {
    test('displayName returns correct names', () {
      expect(TicketStatus.open.displayName, 'Open');
      expect(TicketStatus.inReview.displayName, 'In Review');
      expect(TicketStatus.inProgress.displayName, 'In Progress');
      expect(TicketStatus.resolved.displayName, 'Resolved');
      expect(TicketStatus.closed.displayName, 'Closed');
    });

    test('fromJson creates correct status', () {
      expect(TicketStatus.fromJson('open'), TicketStatus.open);
      expect(TicketStatus.fromJson('in_review'), TicketStatus.inReview);
      expect(TicketStatus.fromJson('in_progress'), TicketStatus.inProgress);
      expect(TicketStatus.fromJson('resolved'), TicketStatus.resolved);
      expect(TicketStatus.fromJson('closed'), TicketStatus.closed);
    });
  });

  group('TicketPriority', () {
    test('displayName returns correct names', () {
      expect(TicketPriority.low.displayName, 'Low');
      expect(TicketPriority.medium.displayName, 'Medium');
      expect(TicketPriority.high.displayName, 'High');
      expect(TicketPriority.critical.displayName, 'Critical');
    });

    test('fromTicketType returns correct priority', () {
      expect(TicketPriority.fromTicketType(TicketType.bug), TicketPriority.high);
      expect(TicketPriority.fromTicketType(TicketType.payment), TicketPriority.critical);
      expect(TicketPriority.fromTicketType(TicketType.account), TicketPriority.high);
      expect(TicketPriority.fromTicketType(TicketType.support), TicketPriority.medium);
      expect(TicketPriority.fromTicketType(TicketType.feedback), TicketPriority.low);
      expect(TicketPriority.fromTicketType(TicketType.featureRequest), TicketPriority.low);
    });
  });

  group('TicketCategory', () {
    test('displayName returns correct names', () {
      expect(TicketCategory.calling.displayName, 'Calling & Video');
      expect(TicketCategory.chat.displayName, 'Chat & Messaging');
      expect(TicketCategory.profile.displayName, 'Profile & Settings');
      expect(TicketCategory.notifications.displayName, 'Notifications');
      expect(TicketCategory.experts.displayName, 'Experts');
      expect(TicketCategory.performance.displayName, 'Performance');
      expect(TicketCategory.other.displayName, 'Other');
    });
  });
}

/// Helper to create a test ticket with specified status.
SupportTicket _createTicket({required TicketStatus status}) {
  return SupportTicket(
    id: 'test-id',
    ticketNumber: 'GH-2026-00001',
    userId: 'user-123',
    userEmail: 'test@example.com',
    type: TicketType.support,
    category: TicketCategory.other,
    subject: 'Test',
    description: 'Test description',
    status: status,
    priority: TicketPriority.medium,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    lastActivityAt: DateTime.now(),
    messageCount: 0,
    hasUnreadSupportMessages: false,
    deviceContext: DeviceContext(
      platform: 'test',
      osVersion: '1.0',
      appVersion: '1.0.0',
      buildNumber: '1',
      locale: 'en_US',
      timezone: 'UTC',
    ),
  );
}
