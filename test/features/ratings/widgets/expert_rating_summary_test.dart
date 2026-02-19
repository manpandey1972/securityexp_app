import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/ratings/widgets/expert_rating_summary.dart';
import 'package:greenhive_app/features/ratings/widgets/star_rating_input.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('ExpertRatingSummary', () {
    group('empty state', () {
      testWidgets('should show empty state when no ratings', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 0.0,
            totalRatings: 0,
          ),
        ));

        expect(find.text('No reviews yet'), findsOneWidget);
      });

      testWidgets('should hide empty state when showEmptyState false', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 0.0,
            totalRatings: 0,
            showEmptyState: false,
          ),
        ));

        expect(find.text('No reviews yet'), findsNothing);
      });
    });

    group('compact variant', () {
      testWidgets('should render compact layout', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 4.5,
            totalRatings: 42,
            variant: 'compact',
          ),
        ));

        expect(find.text('4.5/5'), findsOneWidget);
        expect(find.text('(42)'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      });
    });

    group('normal variant', () {
      testWidgets('should render normal layout with stars', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 4.5,
            totalRatings: 42,
            variant: 'normal',
          ),
        ));

        expect(find.text('4.5/5'), findsOneWidget);
        expect(find.text('(42 reviews)'), findsOneWidget);
        expect(find.byType(StarRatingDisplay), findsOneWidget);
      });

      testWidgets('should show singular review for 1 rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 5.0,
            totalRatings: 1,
            variant: 'normal',
          ),
        ));

        expect(find.text('(1 review)'), findsOneWidget);
      });

      testWidgets('should show chevron when onTap provided', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ExpertRatingSummary(
            averageRating: 4.5,
            totalRatings: 42,
            variant: 'normal',
            onTap: () {},
          ),
        ));

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('should not show chevron when no onTap', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 4.5,
            totalRatings: 42,
            variant: 'normal',
          ),
        ));

        expect(find.byIcon(Icons.chevron_right), findsNothing);
      });
    });

    group('large variant', () {
      testWidgets('should render large layout', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 4.5,
            totalRatings: 42,
            variant: 'large',
          ),
        ));

        expect(find.text('4.5'), findsOneWidget);
        expect(find.text('/5'), findsOneWidget);
        expect(find.text('Based on 42 reviews'), findsOneWidget);
        expect(find.byType(StarRatingDisplay), findsOneWidget);
      });

      testWidgets('should show singular text for 1 review', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const ExpertRatingSummary(
            averageRating: 5.0,
            totalRatings: 1,
            variant: 'large',
          ),
        ));

        expect(find.text('Based on 1 review'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('should call onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          ExpertRatingSummary(
            averageRating: 4.5,
            totalRatings: 42,
            onTap: () => tapped = true,
          ),
        ));

        // Tap on the rating text which is inside the GestureDetector
        await tester.tap(find.text('4.5/5'));
        expect(tapped, isTrue);
      });

      testWidgets('should call onTap on empty state', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          ExpertRatingSummary(
            averageRating: 0.0,
            totalRatings: 0,
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.text('No reviews yet'));
        expect(tapped, isTrue);
      });
    });
  });

  group('ExpertRatingBadge', () {
    testWidgets('should render badge with rating', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ExpertRatingBadge(
          averageRating: 4.5,
          totalRatings: 42,
        ),
      ));

      expect(find.byIcon(Icons.star_rounded), findsWidgets);
    });

    testWidgets('should hide when no ratings', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ExpertRatingBadge(
          averageRating: 0.0,
          totalRatings: 0,
        ),
      ));

      // Should render SizedBox.shrink when totalRatings is 0
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });
}
