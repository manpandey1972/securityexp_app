import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';

void main() {
  group('SnackbarService', () {
    testWidgets('show does nothing when messengerKey has no state', (
      tester,
    ) async {
      // No ScaffoldMessenger is attached to the key, so show should be a no-op
      expect(
        () => SnackbarService.show('hello'),
        returnsNormally,
      );
    });

    testWidgets('show displays message via ScaffoldMessenger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SnackbarService.messengerKey,
          home: const Scaffold(body: Text('content')),
        ),
      );

      SnackbarService.show('Test message');
      await tester.pump(); // trigger snackbar animation

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('show replaces existing snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SnackbarService.messengerKey,
          home: const Scaffold(body: Text('content')),
        ),
      );

      SnackbarService.show('First');
      await tester.pump();
      expect(find.text('First'), findsOneWidget);

      SnackbarService.show('Second');
      await tester.pump(); // start hide animation of first
      await tester.pump(const Duration(milliseconds: 300)); // animate

      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('show accepts custom duration without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SnackbarService.messengerKey,
          home: const Scaffold(body: Text('content')),
        ),
      );

      SnackbarService.show(
        'Short lived',
        duration: const Duration(milliseconds: 500),
      );
      await tester.pump();
      expect(find.text('Short lived'), findsOneWidget);

      // Clean up animations
      await tester.pumpAndSettle();
    });
  });
}
