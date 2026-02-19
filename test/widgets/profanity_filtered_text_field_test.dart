import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/shared/widgets/profanity_filtered_text_field.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_filter_service.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_models.dart';

import '../helpers/widget_test_helpers.dart';
import '../helpers/service_mocks.mocks.dart';

void main() {
  late MockProfanityFilterService mockProfanityFilter;

  setUp(() {
    mockProfanityFilter = MockProfanityFilterService();
    when(mockProfanityFilter.config).thenReturn(const ProfanityConfig());
    registerMock<ProfanityFilterService>(mockProfanityFilter);
  });

  tearDown(() async {
    await resetServiceLocator();
  });

  group('ProfanityFilteredTextField', () {
    testWidgets('should render text field', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          labelText: 'Comment',
          hintText: 'Enter comment',
        ),
      ));

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('should display label text', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          labelText: 'Your Name',
        ),
      ));

      expect(find.text('Your Name'), findsOneWidget);
    });

    testWidgets('should display hint text', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          hintText: 'Type here...',
        ),
      ));

      expect(find.text('Type here...'), findsOneWidget);
    });

    testWidgets('should accept text input', (tester) async {
      String? changedValue;
      await tester.pumpWidget(buildTestableWidget(
        ProfanityFilteredTextField(
          onChanged: (value) => changedValue = value,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), 'hello');
      expect(changedValue, equals('hello'));
    });

    testWidgets('should be disabled when enabled is false', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          enabled: false,
          labelText: 'Disabled',
        ),
      ));

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('should use external controller when provided', (tester) async {
      final controller = TextEditingController(text: 'initial');

      await tester.pumpWidget(buildTestableWidget(
        ProfanityFilteredTextField(
          controller: controller,
        ),
      ));

      expect(find.text('initial'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('should use initialValue when no controller', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          initialValue: 'prefilled',
        ),
      ));

      expect(find.text('prefilled'), findsOneWidget);
    });

    testWidgets('should respect maxLines', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          maxLines: 3,
        ),
      ));

      // Find the underlying TextField to verify maxLines
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, equals(3));
    });

    testWidgets('should show error text', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          errorText: 'Required field',
        ),
      ));

      expect(find.text('Required field'), findsOneWidget);
    });

    testWidgets('should support obscureText for passwords', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfanityFilteredTextField(
          obscureText: true,
        ),
      ));

      expect(find.byType(TextFormField), findsOneWidget);
    });
  });
}
