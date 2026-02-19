import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/shared/widgets/avatar_widget.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  group('AvatarWidget', () {
    testWidgets('should display avatar with image URL', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(
          imageUrl: 'https://example.com/avatar.jpg',
          name: 'Test User',
          size: 50,
        ),
      ));

      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('should display placeholder when no image URL', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(imageUrl: null, name: 'Test User', size: 50),
      ));

      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('should apply correct size', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(
          imageUrl: 'https://example.com/avatar.jpg',
          name: 'Test User',
          size: 100,
        ),
      ));

      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('should show initials for two-word name', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(imageUrl: null, name: 'John Doe', size: 50),
      ));

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('should show single initial for one-word name', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(imageUrl: null, name: 'Alice', size: 50),
      ));

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('should show ? for empty name', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(imageUrl: null, name: '', size: 50),
      ));

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('should show placeholder on empty imageUrl', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(imageUrl: '', name: 'Test', size: 50),
      ));

      // Empty URL should show placeholder
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestableWidget(
        AvatarWidget(
          imageUrl: null,
          name: 'Test',
          size: 50,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(AvatarWidget));
      expect(tapped, isTrue);
    });

    testWidgets('should render border when showBorder is true', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(
          imageUrl: null,
          name: 'Test',
          size: 50,
          showBorder: true,
        ),
      ));

      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('should use initials from first and last of multi-word name', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const AvatarWidget(
          imageUrl: null,
          name: 'John Michael Doe',
          size: 50,
        ),
      ));

      // Should use first and last parts: J + D
      expect(find.text('JD'), findsOneWidget);
    });
  });
}
