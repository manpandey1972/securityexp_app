import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/ratings/widgets/star_rating_input.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('StarRatingInput', () {
    group('rendering', () {
      testWidgets('should render 5 stars', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingInput(rating: 0),
        ));

        // 5 empty stars when rating is 0
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
      });

      testWidgets('should fill stars according to rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingInput(rating: 3),
        ));

        expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
      });

      testWidgets('should fill all stars for rating 5', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingInput(rating: 5),
        ));

        expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
        expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      });

      testWidgets('should show all empty stars for rating 0', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingInput(rating: 0),
        ));

        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
      });
    });

    group('interaction', () {
      testWidgets('should call onRatingChanged when star tapped', (tester) async {
        int? selectedRating;
        await tester.pumpWidget(buildTestableWidget(
          StarRatingInput(
            rating: 0,
            onRatingChanged: (rating) => selectedRating = rating,
          ),
        ));

        // Tap the 4th star
        final stars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(stars.at(3));
        expect(selectedRating, equals(4));
      });

      testWidgets('should call onRatingChanged with 1 for first star', (tester) async {
        int? selectedRating;
        await tester.pumpWidget(buildTestableWidget(
          StarRatingInput(
            rating: 0,
            onRatingChanged: (rating) => selectedRating = rating,
          ),
        ));

        final stars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(stars.first);
        expect(selectedRating, equals(1));
      });

      testWidgets('should not respond when disabled', (tester) async {
        int? selectedRating;
        await tester.pumpWidget(buildTestableWidget(
          StarRatingInput(
            rating: 0,
            onRatingChanged: (rating) => selectedRating = rating,
            enabled: false,
          ),
        ));

        final stars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(stars.first);
        expect(selectedRating, isNull);
      });

      testWidgets('should not respond when no callback provided', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingInput(rating: 3),
        ));

        // Should not throw when tapping without callback
        final stars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(stars.first);
      });
    });

    group('custom styling', () {
      testWidgets('should render with custom size', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingInput(rating: 3, size: 32),
        ));

        expect(find.byType(StarRatingInput), findsOneWidget);
      });
    });
  });

  group('StarRatingDisplay', () {
    group('rendering', () {
      testWidgets('should display full stars for integer rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 4.0),
        ));

        expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));
      });

      testWidgets('should display half star for .5 ratings', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 3.5),
        ));

        expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
        expect(find.byIcon(Icons.star_half_rounded), findsNWidgets(1));
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));
      });

      testWidgets('should display all empty for 0 rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 0.0),
        ));

        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
      });

      testWidgets('should display all full for 5.0 rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 5.0),
        ));

        expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      });
    });

    group('showValue', () {
      testWidgets('should not show numeric value by default', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 4.5),
        ));

        expect(find.text('4.5'), findsNothing);
      });

      testWidgets('should show numeric value when showValue is true', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 4.5, showValue: true),
        ));

        expect(find.text('4.5'), findsOneWidget);
      });
    });

    group('custom styling', () {
      testWidgets('should render with custom size', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const StarRatingDisplay(rating: 3.0, size: 24),
        ));

        expect(find.byType(StarRatingDisplay), findsOneWidget);
      });
    });
  });
}
