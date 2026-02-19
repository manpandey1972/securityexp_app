import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/support/widgets/ticket_card.dart';

void main() {
  group('TicketCard', () {
    testWidgets('displays ticket subject', (tester) async {
      final ticket = _createTestTicket(subject: 'My test subject');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('My test subject'), findsOneWidget);
    });

    testWidgets('displays ticket number', (tester) async {
      final ticket = _createTestTicket(ticketNumber: 'GH-2026-00001');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('#GH-2026-00001'), findsOneWidget);
    });

    testWidgets('displays status chip', (tester) async {
      final ticket = _createTestTicket(status: TicketStatus.open);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('displays category tag', (tester) async {
      final ticket = _createTestTicket(category: TicketCategory.calling);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('Calling & Video'), findsOneWidget);
    });

    testWidgets('displays type tag', (tester) async {
      final ticket = _createTestTicket(type: TicketType.bug);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('Bug Report'), findsOneWidget);
    });

    testWidgets('shows unread indicator when has unread messages', (tester) async {
      final ticket = _createTestTicket(hasUnreadSupportMessages: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('New reply'), findsOneWidget);
    });

    testWidgets('hides unread indicator when no unread messages', (tester) async {
      final ticket = _createTestTicket(hasUnreadSupportMessages: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('New reply'), findsNothing);
    });

    testWidgets('shows rating prompt for resolved unrated tickets', (tester) async {
      final ticket = _createTestTicket(
        status: TicketStatus.resolved,
        userSatisfactionRating: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('Rate'), findsOneWidget);
    });

    testWidgets('hides rating prompt for rated tickets', (tester) async {
      final ticket = _createTestTicket(
        status: TicketStatus.resolved,
        userSatisfactionRating: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      expect(find.text('Rate'), findsNothing);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      bool tapped = false;
      final ticket = _createTestTicket();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCard(
              ticket: ticket,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TicketCard));
      expect(tapped, true);
    });

    testWidgets('displays correct icon for bug type', (tester) async {
      final ticket = _createTestTicket(type: TicketType.bug);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      // There may be multiple bug icons in the widget tree (header and elsewhere)
      expect(find.byIcon(Icons.bug_report), findsWidgets);
    });

    testWidgets('displays correct icon for feature request type', (tester) async {
      final ticket = _createTestTicket(type: TicketType.featureRequest);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TicketCard(ticket: ticket)),
        ),
      );

      // There may be multiple lightbulb icons in the widget tree
      expect(find.byIcon(Icons.lightbulb_outline), findsWidgets);
    });
  });
}

/// Helper to create a test ticket.
SupportTicket _createTestTicket({
  String subject = 'Test Subject',
  String ticketNumber = 'GH-2026-00001',
  TicketStatus status = TicketStatus.open,
  TicketType type = TicketType.support,
  TicketCategory category = TicketCategory.other,
  bool hasUnreadSupportMessages = false,
  int? userSatisfactionRating,
}) {
  return SupportTicket(
    id: 'test-ticket-id',
    ticketNumber: ticketNumber,
    userId: 'test-user-id',
    userEmail: 'test@example.com',
    type: type,
    category: category,
    subject: subject,
    description: 'Test description',
    status: status,
    priority: TicketPriority.medium,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    lastActivityAt: DateTime.now(),
    messageCount: 1,
    hasUnreadSupportMessages: hasUnreadSupportMessages,
    userSatisfactionRating: userSatisfactionRating,
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
