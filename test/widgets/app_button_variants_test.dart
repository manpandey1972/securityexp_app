import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/shared/widgets/app_button_variants.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  group('AppButtonVariants', () {
    group('elevatedSmall', () {
      testWidgets('should render with label', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedSmall(
            onPressed: () {},
            label: 'Small Button',
          ),
        ));

        expect(find.text('Small Button'), findsOneWidget);
        expect(find.bySubtype<ElevatedButton>(), findsOneWidget);
      });

      testWidgets('should render with icon', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedSmall(
            onPressed: () {},
            label: 'With Icon',
            icon: Icons.add,
          ),
        ));

        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should show loading indicator when isLoading', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedSmall(
            onPressed: () {},
            label: 'Loading',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should be disabled when isEnabled is false', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedSmall(
            onPressed: () => tapped = true,
            label: 'Disabled',
            isEnabled: false,
          ),
        ));

        await tester.tap(find.bySubtype<ElevatedButton>());
        expect(tapped, isFalse);
      });

      testWidgets('should call onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedSmall(
            onPressed: () => tapped = true,
            label: 'Tap Me',
          ),
        ));

        await tester.tap(find.bySubtype<ElevatedButton>());
        expect(tapped, isTrue);
      });
    });

    group('elevatedLarge', () {
      testWidgets('should render with label', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedLarge(
            onPressed: () {},
            label: 'Large Button',
          ),
        ));

        expect(find.text('Large Button'), findsOneWidget);
        expect(find.bySubtype<ElevatedButton>(), findsOneWidget);
      });

      testWidgets('should show loading indicator', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedLarge(
            onPressed: () {},
            label: 'Loading',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('elevatedFullWidth', () {
      testWidgets('should render full width', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedFullWidth(
            onPressed: () {},
            label: 'Full Width',
          ),
        ));

        expect(find.text('Full Width'), findsOneWidget);
      });

      testWidgets('should be disabled when loading', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.elevatedFullWidth(
            onPressed: () => tapped = true,
            label: 'Loading',
            isLoading: true,
          ),
        ));

        await tester.tap(find.bySubtype<ElevatedButton>());
        expect(tapped, isFalse);
      });
    });

    group('outlinedSmall', () {
      testWidgets('should render outlined button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.outlinedSmall(
            onPressed: () {},
            label: 'Outlined',
          ),
        ));

        expect(find.text('Outlined'), findsOneWidget);
        expect(find.bySubtype<OutlinedButton>(), findsOneWidget);
      });

      testWidgets('should be disabled when isEnabled is false', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.outlinedSmall(
            onPressed: () => tapped = true,
            label: 'Disabled',
            isEnabled: false,
          ),
        ));

        await tester.tap(find.bySubtype<OutlinedButton>());
        expect(tapped, isFalse);
      });
    });

    group('outlinedLarge', () {
      testWidgets('should render large outlined button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.outlinedLarge(
            onPressed: () {},
            label: 'Large Outlined',
          ),
        ));

        expect(find.text('Large Outlined'), findsOneWidget);
        expect(find.bySubtype<OutlinedButton>(), findsOneWidget);
      });
    });

    group('outlinedFullWidth', () {
      testWidgets('should render full width outlined button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.outlinedFullWidth(
            onPressed: () {},
            label: 'Full Outlined',
          ),
        ));

        expect(find.text('Full Outlined'), findsOneWidget);
      });
    });

    group('textSmall', () {
      testWidgets('should render text button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.textSmall(
            onPressed: () {},
            label: 'Text',
          ),
        ));

        expect(find.text('Text'), findsOneWidget);
        expect(find.bySubtype<TextButton>(), findsOneWidget);
      });
    });

    group('textLarge', () {
      testWidgets('should render large text button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.textLarge(
            onPressed: () {},
            label: 'Large Text',
          ),
        ));

        expect(find.text('Large Text'), findsOneWidget);
        expect(find.bySubtype<TextButton>(), findsOneWidget);
      });
    });

    group('textFullWidth', () {
      testWidgets('should render full width text button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.textFullWidth(
            onPressed: () {},
            label: 'Full Text',
          ),
        ));

        expect(find.text('Full Text'), findsOneWidget);
      });
    });

    group('iconButton', () {
      testWidgets('should render icon button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.iconButton(
            onPressed: () {},
            icon: Icons.delete,
          ),
        ));

        expect(find.byIcon(Icons.delete), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      });

      testWidgets('should call onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.iconButton(
            onPressed: () => tapped = true,
            icon: Icons.delete,
          ),
        ));

        await tester.tap(find.byType(IconButton));
        expect(tapped, isTrue);
      });

      testWidgets('should be disabled when isEnabled is false', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.iconButton(
            onPressed: () => tapped = true,
            icon: Icons.delete,
            isEnabled: false,
          ),
        ));

        await tester.tap(find.byType(IconButton));
        expect(tapped, isFalse);
      });
    });

    group('primary', () {
      testWidgets('should render primary button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.primary(
            onPressed: () {},
            label: 'Submit',
          ),
        ));

        expect(find.text('Submit'), findsOneWidget);
        expect(find.bySubtype<ElevatedButton>(), findsOneWidget);
      });

      testWidgets('should show loading spinner', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.primary(
            onPressed: () {},
            label: 'Submit',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should not call onPressed when loading', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.primary(
            onPressed: () => tapped = true,
            label: 'Submit',
            isLoading: true,
          ),
        ));

        await tester.tap(find.bySubtype<ElevatedButton>());
        expect(tapped, isFalse);
      });

      testWidgets('should not call onPressed when disabled', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.primary(
            onPressed: () => tapped = true,
            label: 'Submit',
            isEnabled: false,
          ),
        ));

        await tester.tap(find.bySubtype<ElevatedButton>());
        expect(tapped, isFalse);
      });
    });

    group('secondary', () {
      testWidgets('should render secondary button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.secondary(
            onPressed: () {},
            label: 'Skip',
          ),
        ));

        expect(find.text('Skip'), findsOneWidget);
        expect(find.bySubtype<OutlinedButton>(), findsOneWidget);
      });

      testWidgets('should show loading spinner', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.secondary(
            onPressed: () {},
            label: 'Skip',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('destructive', () {
      testWidgets('should render destructive button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.destructive(
            onPressed: () {},
            label: 'Delete',
          ),
        ));

        expect(find.text('Delete'), findsOneWidget);
        expect(find.bySubtype<TextButton>(), findsOneWidget);
      });

      testWidgets('should show loading spinner', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.destructive(
            onPressed: () {},
            label: 'Delete',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('dialogAction', () {
      testWidgets('should render dialog action button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.dialogAction(
            onPressed: () {},
            label: 'OK',
          ),
        ));

        expect(find.text('OK'), findsOneWidget);
        expect(find.bySubtype<TextButton>(), findsOneWidget);
      });

      testWidgets('should call onPressed on tap', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.dialogAction(
            onPressed: () => tapped = true,
            label: 'OK',
          ),
        ));

        await tester.tap(find.bySubtype<TextButton>());
        expect(tapped, isTrue);
      });
    });

    group('dialogCancel', () {
      testWidgets('should render with default Cancel label', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.dialogCancel(onPressed: () {}),
        ));

        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('should render with custom label', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.dialogCancel(
            onPressed: () {},
            label: 'Dismiss',
          ),
        ));

        expect(find.text('Dismiss'), findsOneWidget);
      });
    });

    group('dialogConfirm', () {
      testWidgets('should render confirm button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.dialogConfirm(
            onPressed: () {},
            label: 'Confirm',
          ),
        ));

        expect(find.text('Confirm'), findsOneWidget);
        expect(find.bySubtype<TextButton>(), findsOneWidget);
      });
    });

    group('dialogDestructive', () {
      testWidgets('should render destructive dialog button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.dialogDestructive(
            onPressed: () {},
            label: 'Delete',
          ),
        ));

        expect(find.text('Delete'), findsOneWidget);
      });
    });

    group('compact', () {
      testWidgets('should render compact button', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.compact(
            onPressed: () {},
            label: 'Edit',
          ),
        ));

        expect(find.text('Edit'), findsOneWidget);
        expect(find.bySubtype<ElevatedButton>(), findsOneWidget);
      });

      testWidgets('should show loading indicator', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.compact(
            onPressed: () {},
            label: 'Edit',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('actionWithIcon', () {
      testWidgets('should render button with icon and label', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.actionWithIcon(
            onPressed: () {},
            label: 'Retry',
            icon: Icons.refresh,
          ),
        ));

        expect(find.text('Retry'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
      });

      testWidgets('should show loading indicator instead of icon', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AppButtonVariants.actionWithIcon(
            onPressed: () {},
            label: 'Retry',
            icon: Icons.refresh,
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}
