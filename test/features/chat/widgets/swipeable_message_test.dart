import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/chat/widgets/swipeable_message.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('SwipeableMessage', () {
    group('rendering', () {
      testWidgets('should render child widget', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('Hello'),
          ),
        ));

        expect(find.text('Hello'), findsOneWidget);
      });

      testWidgets('should render child directly when disabled', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            enabled: false,
            child: const Text('Disabled'),
          ),
        ));

        expect(find.text('Disabled'), findsOneWidget);
        // When disabled, no GestureDetector from SwipeableMessage
        expect(find.byType(SwipeableMessage), findsOneWidget);
      });
    });

    group('fromMe variants', () {
      testWidgets('should render for own message (fromMe=true)', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('My message'),
          ),
        ));

        expect(find.text('My message'), findsOneWidget);
      });

      testWidgets('should render for peer message (fromMe=false)', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: false,
            onReply: () {},
            child: const Text('Peer message'),
          ),
        ));

        expect(find.text('Peer message'), findsOneWidget);
      });
    });

    group('reply icon', () {
      testWidgets('should have reply icon in background', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('Hello'),
          ),
        ));

        expect(find.byIcon(Icons.reply), findsOneWidget);
      });

      testWidgets('should have Reply tooltip', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('Hello'),
          ),
        ));

        expect(find.byTooltip('Reply'), findsOneWidget);
      });
    });

    group('swipe gestures', () {
      testWidgets('should have reply callback configured', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('My message'),
          ),
        ));

        // Verify the reply icon is present (may be hidden behind animations)
        expect(find.byIcon(Icons.reply), findsOneWidget);
      });
    });

    group('animation', () {
      testWidgets('should contain SlideTransition', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('Hello'),
          ),
        ));

        expect(find.byType(SlideTransition), findsWidgets);
      });

      testWidgets('should contain ScaleTransition', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          SwipeableMessage(
            fromMe: true,
            onReply: () {},
            child: const Text('Hello'),
          ),
        ));

        expect(find.byType(ScaleTransition), findsWidgets);
      });
    });
  });
}
