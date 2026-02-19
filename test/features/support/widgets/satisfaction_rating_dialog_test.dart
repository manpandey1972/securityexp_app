import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/support/widgets/satisfaction_rating_dialog.dart';

void main() {
  group('SatisfactionRatingDialog', () {
    Widget buildDialog({
      int? selectedRating,
      String comment = '',
      ValueChanged<int>? onRatingChanged,
      ValueChanged<String>? onCommentChanged,
      VoidCallback? onSubmit,
      VoidCallback? onDismiss,
      bool isSubmitting = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SatisfactionRatingDialog(
            selectedRating: selectedRating,
            comment: comment,
            onRatingChanged: onRatingChanged ?? (_) {},
            onCommentChanged: onCommentChanged ?? (_) {},
            onSubmit: onSubmit ?? () {},
            onDismiss: onDismiss ?? () {},
            isSubmitting: isSubmitting,
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('should display title', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.text('Rate Your Experience'), findsOneWidget);
      });

      testWidgets('should display subtitle', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.text('How was your support experience?'), findsOneWidget);
      });

      testWidgets('should show 5 star icons', (tester) async {
        await tester.pumpWidget(buildDialog());

        // 5 empty stars initially (no rating selected)
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
      });

      testWidgets('should show comment text field', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('should show Maybe Later button', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.text('Maybe Later'), findsOneWidget);
      });

      testWidgets('should show Submit button', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.text('Submit'), findsOneWidget);
      });

      testWidgets('should show star icon in header', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.byIcon(Icons.star_rounded), findsWidgets);
      });
    });

    group('star rating interaction', () {
      testWidgets('should call onRatingChanged when star tapped', (tester) async {
        int? selectedRating;
        await tester.pumpWidget(buildDialog(
          onRatingChanged: (rating) => selectedRating = rating,
        ));

        // Tap the 3rd star (index 2)
        final stars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(stars.at(2));
        expect(selectedRating, equals(3));
      });

      testWidgets('should show filled stars when rating selected', (tester) async {
        await tester.pumpWidget(buildDialog(selectedRating: 3));

        // 3 filled + 2 empty
        expect(find.byIcon(Icons.star_rounded), findsWidgets);
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
      });

      testWidgets('should show all stars filled for rating 5', (tester) async {
        await tester.pumpWidget(buildDialog(selectedRating: 5));

        expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      });
    });

    group('rating labels', () {
      testWidgets('should show label when no rating selected', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.text('Tap to rate'), findsOneWidget);
      });
    });

    group('comment', () {
      testWidgets('should call onCommentChanged when text entered', (tester) async {
        String? commentValue;
        await tester.pumpWidget(buildDialog(
          onCommentChanged: (value) => commentValue = value,
        ));

        await tester.enterText(find.byType(TextField), 'Great service!');
        expect(commentValue, equals('Great service!'));
      });

      testWidgets('should show hint text', (tester) async {
        await tester.pumpWidget(buildDialog());

        expect(find.text('Additional feedback (optional)'), findsOneWidget);
      });
    });

    group('submit button', () {
      testWidgets('should be disabled when no rating selected', (tester) async {
        var submitted = false;
        await tester.pumpWidget(buildDialog(
          selectedRating: null,
          onSubmit: () => submitted = true,
        ));

        await tester.tap(find.text('Submit'));
        expect(submitted, isFalse);
      });

      testWidgets('should be enabled when rating selected', (tester) async {
        var submitted = false;
        await tester.pumpWidget(buildDialog(
          selectedRating: 4,
          onSubmit: () => submitted = true,
        ));

        await tester.tap(find.text('Submit'));
        expect(submitted, isTrue);
      });

      testWidgets('should be disabled when submitting', (tester) async {
        await tester.pumpWidget(buildDialog(
          selectedRating: 4,
          isSubmitting: true,
        ));

        // When submitting, the submit button text is replaced with spinner
        expect(find.text('Submit'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should show loading indicator when submitting', (tester) async {
        await tester.pumpWidget(buildDialog(
          selectedRating: 4,
          isSubmitting: true,
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('dismiss button', () {
      testWidgets('should call onDismiss when Maybe Later tapped', (tester) async {
        var dismissed = false;
        await tester.pumpWidget(buildDialog(
          onDismiss: () => dismissed = true,
        ));

        await tester.tap(find.text('Maybe Later'));
        expect(dismissed, isTrue);
      });

      testWidgets('should be disabled when submitting', (tester) async {
        var dismissed = false;
        await tester.pumpWidget(buildDialog(
          isSubmitting: true,
          onDismiss: () => dismissed = true,
        ));

        await tester.tap(find.text('Maybe Later'));
        expect(dismissed, isFalse);
      });
    });
  });
}
