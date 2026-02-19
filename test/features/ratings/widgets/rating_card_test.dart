import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/ratings/data/models/rating.dart';
import 'package:greenhive_app/features/ratings/widgets/rating_card.dart';
import 'package:greenhive_app/features/ratings/widgets/star_rating_input.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  Rating createTestRating({
    String id = 'rating-1',
    String expertId = 'expert-1',
    String expertName = 'Expert',
    String userId = 'user-1',
    String? userName = 'John Doe',
    int stars = 4,
    String? comment,
    bool isAnonymous = false,
    DateTime? createdAt,
  }) {
    return Rating(
      id: id,
      expertId: expertId,
      expertName: expertName,
      userId: userId,
      userName: userName,
      stars: stars,
      comment: comment,
      isAnonymous: isAnonymous,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  group('RatingCard', () {
    group('rendering', () {
      testWidgets('should display user name', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(userName: 'Jane Smith'),
          ),
        ));

        expect(find.text('Jane Smith'), findsOneWidget);
      });

      testWidgets('should display Anonymous for anonymous rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(isAnonymous: true),
          ),
        ));

        expect(find.text('Anonymous'), findsOneWidget);
      });

      testWidgets('should display User when no userName', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(userName: null),
          ),
        ));

        expect(find.text('User'), findsOneWidget);
      });

      testWidgets('should display star rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(stars: 5),
          ),
        ));

        expect(find.byType(StarRatingDisplay), findsOneWidget);
      });

      testWidgets('should display comment when present', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(comment: 'Great expert!'),
          ),
        ));

        expect(find.text('Great expert!'), findsOneWidget);
      });

      testWidgets('should not display comment section when no comment', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(comment: null),
          ),
        ));

        expect(find.text('Great expert!'), findsNothing);
      });

      testWidgets('should hide comment when showComment is false', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(comment: 'Hidden comment'),
            showComment: false,
          ),
        ));

        expect(find.text('Hidden comment'), findsNothing);
      });

      testWidgets('should show user initial in avatar', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(userName: 'Jane'),
          ),
        ));

        expect(find.text('J'), findsOneWidget);
      });

      testWidgets('should show A in avatar for anonymous', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(isAnonymous: true),
          ),
        ));

        expect(find.text('A'), findsOneWidget);
      });
    });

    group('date formatting', () {
      testWidgets('should display Today for current date', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(createdAt: DateTime.now()),
          ),
        ));

        expect(find.text('Today'), findsOneWidget);
      });

      testWidgets('should display Yesterday for previous day', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ),
        ));

        expect(find.text('Yesterday'), findsOneWidget);
      });

      testWidgets('should display days ago for recent dates', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(
              createdAt: DateTime.now().subtract(const Duration(days: 3)),
            ),
          ),
        ));

        expect(find.text('3 days ago'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('should call onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          RatingCard(
            rating: createTestRating(),
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(InkWell).first);
        expect(tapped, isTrue);
      });
    });
  });

  group('RatingCardCompact', () {
    group('rendering', () {
      testWidgets('should display user name', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCardCompact(
            rating: createTestRating(userName: 'Bob'),
          ),
        ));

        expect(find.text('Bob'), findsOneWidget);
      });

      testWidgets('should display star rating', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCardCompact(
            rating: createTestRating(stars: 3),
          ),
        ));

        expect(find.byType(StarRatingDisplay), findsOneWidget);
      });

      testWidgets('should display comment preview', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCardCompact(
            rating: createTestRating(comment: 'Very helpful session'),
          ),
        ));

        expect(find.text('Very helpful session'), findsOneWidget);
      });

      testWidgets('should not show comment when absent', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          RatingCardCompact(
            rating: createTestRating(comment: null),
          ),
        ));

        // Only name and stars should be visible
        expect(find.byType(StarRatingDisplay), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('should call onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          RatingCardCompact(
            rating: createTestRating(),
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(InkWell).first);
        expect(tapped, isTrue);
      });
    });
  });
}
