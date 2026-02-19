import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/features/chat/widgets/linkified_text.dart';

import '../../../helpers/widget_test_helpers.dart';
import '../../../helpers/service_mocks.mocks.dart';

void main() {
  late MockAppLogger mockLogger;

  setUp(() {
    mockLogger = MockAppLogger();
    registerMock<AppLogger>(mockLogger);
  });

  tearDown(() async {
    await resetServiceLocator();
  });

  group('LinkifiedText', () {
    group('plain text', () {
      testWidgets('should render plain text without links', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Hello, world!'),
        ));

        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('should render empty text', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText(''),
        ));

        expect(find.byType(SelectableText), findsOneWidget);
      });
    });

    group('URL detection', () {
      testWidgets('should render text with http URL', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Visit http://example.com for more'),
        ));

        // The widget should be present and render the full text
        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('should render text with https URL', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Check https://flutter.dev'),
        ));

        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('should render text with www URL', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Visit www.example.com'),
        ));

        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('should handle multiple URLs in text', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Visit https://a.com and https://b.com'),
        ));

        expect(find.byType(SelectableText), findsOneWidget);
      });
    });

    group('selectable mode', () {
      testWidgets('should use SelectableText when selectable is true', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Hello', selectable: true),
        ));

        expect(find.byType(SelectableText), findsOneWidget);
      });

      testWidgets('should use Text.rich when selectable is false', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText('Hello', selectable: false),
        ));

        // Should not have SelectableText
        expect(find.byType(SelectableText), findsNothing);
        // Should have a RichText (from Text.rich)
        expect(find.byType(RichText), findsOneWidget);
      });
    });

    group('styling', () {
      testWidgets('should apply custom style', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          LinkifiedText(
            'Styled text',
            style: const TextStyle(fontSize: 20, color: Colors.red),
          ),
        ));

        expect(find.byType(SelectableText), findsOneWidget);
      });
    });
  });
}
