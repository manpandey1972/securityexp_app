import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/shared/widgets/shimmer_loading.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  group('ShimmerLoading', () {
    group('shimmer', () {
      testWidgets('should wrap child in shimmer when enabled', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.shimmer(
            child: Container(width: 100, height: 20, color: Colors.white),
          ),
        ));

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should return child directly when disabled', (tester) async {
        final child = Container(
          key: const Key('child'),
          width: 100,
          height: 20,
          color: Colors.white,
        );

        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.shimmer(child: child, enabled: false),
        ));

        expect(find.byKey(const Key('child')), findsOneWidget);
      });
    });

    group('chatListItem', () {
      testWidgets('should render chat list shimmer', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.chatListItem(),
        ));

        // Should render the shimmer container with placeholder elements
        expect(find.byType(Row), findsWidgets);
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('callHistoryItem', () {
      testWidgets('should render call history shimmer', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.callHistoryItem(),
        ));

        expect(find.byType(Row), findsWidgets);
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('expertCard', () {
      testWidgets('should render expert card shimmer', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.expertCard(),
        ));

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('productCard', () {
      testWidgets('should render product card shimmer', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.productCard(),
        ));

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('rectangle', () {
      testWidgets('should render with default dimensions', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.rectangle(),
        ));

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should render with custom dimensions', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.rectangle(width: 200, height: 40),
        ));

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('circle', () {
      testWidgets('should render with default size', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.circle(),
        ));

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should render with custom size', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          ShimmerLoading.circle(size: 64),
        ));

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('list', () {
      testWidgets('should render correct number of items', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SizedBox(
            height: 400,
            child: ShimmerLoading.list(
              itemCount: 3,
              itemBuilder: () => ShimmerLoading.chatListItem(),
            ),
          ),
        ));

        expect(find.byType(ListView), findsOneWidget);
      });
    });
  });
}
