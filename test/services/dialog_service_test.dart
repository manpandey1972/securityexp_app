import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/shared/services/dialog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DialogService', () {
    group('showEditDialog', () {
      testWidgets('should show dialog with title and initial text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await DialogService.showEditDialog(
                        context,
                        title: 'Edit Name',
                        initialText: 'John Doe',
                        saveButtonLabel: 'Save',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        // Tap the button to open the dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog content
        expect(find.text('Edit Name'), findsOneWidget);
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        
        // Dismiss dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });

      testWidgets('should return null on cancel', (tester) async {
        String? result = 'initial';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await DialogService.showEditDialog(
                        context,
                        title: 'Edit',
                        initialText: 'Test',
                        saveButtonLabel: 'Save',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(result, isNull);
      });
    });

    group('showConfirmationDialog', () {
      testWidgets('should return false on cancel', (tester) async {
        bool? result = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await DialogService.showConfirmationDialog(
                        context,
                        title: 'Confirm Action',
                        message: 'Are you sure?',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog content
        expect(find.text('Confirm Action'), findsOneWidget);
        expect(find.text('Are you sure?'), findsOneWidget);

        // Tap cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(result, false);
      });

      testWidgets('should return true on confirm', (tester) async {
        bool? result = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await DialogService.showConfirmationDialog(
                        context,
                        title: 'Confirm',
                        message: 'Proceed?',
                        confirmLabel: 'Yes',
                        cancelLabel: 'No',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap confirm
        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        expect(result, true);
      });
    });

    group('showInfoDialog', () {
      testWidgets('should show info dialog', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await DialogService.showInfoDialog(
                        context,
                        title: 'Information',
                        message: 'This is an important message.',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Information'), findsOneWidget);
        expect(find.text('This is an important message.'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        
        // Dismiss
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      });

      testWidgets('should dismiss on button press', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await DialogService.showInfoDialog(
                        context,
                        title: 'Info',
                        message: 'Message',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Info'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Info'), findsNothing);
      });
    });

    group('showErrorDialog', () {
      testWidgets('should show error dialog with dismiss button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await DialogService.showErrorDialog(
                        context,
                        title: 'Error',
                        error: 'Something went wrong',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
        
        // Dismiss
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();
      });
    });

    group('showLoadingDialog', () {
      testWidgets('should show loading dialog with progress indicator', (tester) async {
        late BuildContext savedContext;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  savedContext = context;
                  return ElevatedButton(
                    onPressed: () {
                      DialogService.showLoadingDialog(
                        context,
                        message: 'Please wait...',
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pump(); // Don't use pumpAndSettle as CircularProgressIndicator animates

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Please wait...'), findsOneWidget);
        
        // Dismiss programmatically
        DialogService.dismissDialog(savedContext);
        await tester.pumpAndSettle();
      });
    });

    group('dismissDialog', () {
      testWidgets('should dismiss dialog programmatically', (tester) async {
        late BuildContext savedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  savedContext = context;
                  return ElevatedButton(
                    onPressed: () {
                      DialogService.showLoadingDialog(context);
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Dismiss the dialog
        DialogService.dismissDialog(savedContext);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });
}
