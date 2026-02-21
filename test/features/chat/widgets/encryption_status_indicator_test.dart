import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/chat/widgets/encryption_status_indicator.dart';

void main() {
  // ===========================================================================
  // EncryptionStatusIndicator
  // ===========================================================================

  group('EncryptionStatusIndicator', () {
    testWidgets('should show nothing when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EncryptionStatusIndicator(isEnabled: false),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.text('End-to-end encrypted'), findsNothing);
    });

    testWidgets('should show lock icon and text when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EncryptionStatusIndicator(isEnabled: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('End-to-end encrypted'), findsOneWidget);
    });

    testWidgets('should show only icon when showLabel is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EncryptionStatusIndicator(
              isEnabled: true,
              showLabel: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('End-to-end encrypted'), findsNothing);
    });
  });

  // ===========================================================================
  // MessageEncryptionBadge
  // ===========================================================================

  group('MessageEncryptionBadge', () {
    testWidgets('should show nothing for unencrypted messages',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageEncryptionBadge(isEncrypted: false),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
    });

    testWidgets('should show lock icon for encrypted messages',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageEncryptionBadge(isEncrypted: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('should show open lock icon on decryption failure',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageEncryptionBadge(
              isEncrypted: true,
              decryptionFailed: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });
  });
}
