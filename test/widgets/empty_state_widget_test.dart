import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/shared/widgets/empty_state_widget.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  group('EmptyStateWidget', () {
    group('default constructor', () {
      testWidgets('should render title and description', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const EmptyStateWidget(
            title: 'No Items',
            description: 'There are no items to display.',
          ),
        ));

        expect(find.text('No Items'), findsOneWidget);
        expect(find.text('There are no items to display.'), findsOneWidget);
      });

      testWidgets('should render icon', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Empty',
            description: 'No items',
          ),
        ));

        expect(find.byIcon(Icons.inbox), findsOneWidget);
      });

      testWidgets('should show action button when provided', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget(
            title: 'No Items',
            description: 'No items to display.',
            actionLabel: 'Refresh',
            onAction: () {},
          ),
        ));

        expect(find.text('Refresh'), findsOneWidget);
      });

      testWidgets('should call onAction when button tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget(
            title: 'No Items',
            description: 'No items to display.',
            actionLabel: 'Refresh',
            onAction: () => tapped = true,
          ),
        ));

        await tester.tap(find.text('Refresh'));
        expect(tapped, isTrue);
      });

      testWidgets('should hide action button when showAction is false', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget(
            title: 'No Items',
            description: 'No items.',
            actionLabel: 'Refresh',
            onAction: () {},
            showAction: false,
          ),
        ));

        expect(find.text('Refresh'), findsNothing);
      });

      testWidgets('should hide action when no label provided', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget(
            title: 'No Items',
            description: 'No items.',
            onAction: () {},
          ),
        ));

        // No action button without label
        expect(find.byType(ElevatedButton), findsNothing);
      });
    });

    group('list factory', () {
      testWidgets('should render list empty state', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.list(
            title: 'No Messages',
            description: 'Start a conversation.',
          ),
        ));

        expect(find.text('No Messages'), findsOneWidget);
        expect(find.text('Start a conversation.'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      });
    });

    group('search factory', () {
      testWidgets('should render search empty state with query', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.search(query: 'flutter'),
        ));

        expect(find.text('No Results Found'), findsOneWidget);
        expect(find.text('No items found for "flutter"'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });
    });

    group('error factory', () {
      testWidgets('should render error state', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.error(
            title: 'Something went wrong',
            description: 'An error occurred.',
          ),
        ));

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('An error occurred.'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('should show Try Again button by default', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.error(
            title: 'Error',
            description: 'Failed',
            onAction: () {},
          ),
        ));

        expect(find.text('Try Again'), findsOneWidget);
      });
    });

    group('noConnection factory', () {
      testWidgets('should render no connection state', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.noConnection(),
        ));

        expect(find.text('No Connection'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      });

      testWidgets('should show Retry button by default', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.noConnection(onAction: () {}),
        ));

        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('noPermission factory', () {
      testWidgets('should render no permission state', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          EmptyStateWidget.noPermission(
            title: 'Access Denied',
            description: 'You need permission.',
          ),
        ));

        expect(find.text('Access Denied'), findsOneWidget);
        expect(find.text('You need permission.'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });
    });
  });
}
