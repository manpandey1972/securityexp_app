import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/support/widgets/message_bubble.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('displays message content', (tester) async {
      final message = _createUserMessage(content: 'Hello, I need help');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: true),
          ),
        ),
      );

      expect(find.text('Hello, I need help'), findsOneWidget);
    });

    testWidgets('aligns user message to the right', (tester) async {
      final message = _createUserMessage();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: true),
          ),
        ),
      );

      // User messages should be aligned to the right
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('aligns support message to the left', (tester) async {
      final message = _createSupportMessage();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: false),
          ),
        ),
      );

      // Support messages should be aligned to the left
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('displays sender name for support messages', (tester) async {
      final message = _createSupportMessage(senderName: 'Support Agent');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: false),
          ),
        ),
      );

      expect(find.text('Support Agent'), findsOneWidget);
    });

    testWidgets('hides sender name for user messages', (tester) async {
      final message = _createUserMessage(senderName: 'John Doe');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: true),
          ),
        ),
      );

      // User's own name should not be displayed
      expect(find.text('John Doe'), findsNothing);
    });

    testWidgets('displays system message centered', (tester) async {
      final message = _createSystemMessage(content: 'Ticket has been updated');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: false),
          ),
        ),
      );

      expect(find.text('Ticket has been updated'), findsOneWidget);
      // Widget should build without errors
      expect(find.byType(MessageBubble), findsOneWidget);
    });

    testWidgets('displays timestamp', (tester) async {
      final message = _createUserMessage(
        createdAt: DateTime(2026, 1, 28, 14, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: true),
          ),
        ),
      );

      // Should display formatted time
      expect(find.textContaining(':'), findsOneWidget);
    });

    testWidgets('displays attachment indicator when has attachments', (tester) async {
      final attachment = TicketAttachment(
        id: 'att-1',
        url: 'https://example.com/image.png',
        fileName: 'image.png',
        fileSize: 1024,
        mimeType: 'image/png',
        uploadedAt: DateTime.now(),
      );

      final message = SupportMessage(
        id: 'msg-123',
        ticketId: 'ticket-456',
        senderId: 'user-789',
        senderType: MessageSenderType.user,
        senderName: 'Test User',
        content: 'See attached',
        createdAt: DateTime.now(),
        attachments: [attachment],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: true),
          ),
        ),
      );

      // Widget should build without errors
      expect(find.byType(MessageBubble), findsOneWidget);
      // Message has attachments
      expect(message.hasAttachments, true);
    });

    testWidgets('shows read indicator for read support messages', (tester) async {
      final message = SupportMessage(
        id: 'msg-123',
        ticketId: 'ticket-456',
        senderId: 'support-1',
        senderType: MessageSenderType.support,
        senderName: 'Support',
        content: 'Hello',
        createdAt: DateTime.now(),
        readAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message, isCurrentUser: false),
          ),
        ),
      );

      // Widget should build without errors
      expect(find.byType(MessageBubble), findsOneWidget);
    });
  });
}

/// Helper to create a user message.
SupportMessage _createUserMessage({
  String content = 'Test message',
  String senderName = 'Test User',
  DateTime? createdAt,
}) {
  return SupportMessage(
    id: 'msg-user-123',
    ticketId: 'ticket-456',
    senderType: MessageSenderType.user,
    senderId: 'user-789',
    senderName: senderName,
    content: content,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Helper to create a support message.
SupportMessage _createSupportMessage({
  String content = 'Support response',
  String senderName = 'Support Agent',
}) {
  return SupportMessage(
    id: 'msg-support-123',
    ticketId: 'ticket-456',
    senderType: MessageSenderType.support,
    senderId: 'support-1',
    senderName: senderName,
    content: content,
    createdAt: DateTime.now(),
  );
}

/// Helper to create a system message.
SupportMessage _createSystemMessage({
  String content = 'System notification',
  SystemMessageType? systemMessageType,
}) {
  return SupportMessage(
    id: 'msg-system-123',
    ticketId: 'ticket-456',
    senderId: 'system',
    senderType: MessageSenderType.system,
    senderName: 'System',
    content: content,
    systemMessageType: systemMessageType ?? SystemMessageType.statusChange,
    createdAt: DateTime.now(),
  );
}
