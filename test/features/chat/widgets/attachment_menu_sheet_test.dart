import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/chat/widgets/attachment_menu_sheet.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('AttachmentMenuSheet', () {
    group('visibility', () {
      testWidgets('should show menu when showSheet is true', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentMenuSheet(
            showSheet: true,
            onDocumentTap: () {},
            onPhotosTap: () {},
          ),
        ));

        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Document'), findsOneWidget);
      });

      testWidgets('should hide menu when showSheet is false', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentMenuSheet(
            showSheet: false,
            onDocumentTap: () {},
            onPhotosTap: () {},
          ),
        ));

        expect(find.text('Photos'), findsNothing);
        expect(find.text('Document'), findsNothing);
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    group('interactions', () {
      testWidgets('should call onPhotosTap when Photos tapped', (tester) async {
        var photosTapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AttachmentMenuSheet(
            showSheet: true,
            onDocumentTap: () {},
            onPhotosTap: () => photosTapped = true,
          ),
        ));

        await tester.tap(find.text('Photos'));
        await tester.pumpAndSettle();
        expect(photosTapped, isTrue);
      });

      testWidgets('should call onDocumentTap when Document tapped', (tester) async {
        var docTapped = false;
        await tester.pumpWidget(buildTestableWidget(
          AttachmentMenuSheet(
            showSheet: true,
            onDocumentTap: () => docTapped = true,
            onPhotosTap: () {},
          ),
        ));

        await tester.tap(find.text('Document'));
        await tester.pumpAndSettle();
        expect(docTapped, isTrue);
      });
    });

    group('icons', () {
      testWidgets('should show photo library icon', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentMenuSheet(
            showSheet: true,
            onDocumentTap: () {},
            onPhotosTap: () {},
          ),
        ));

        expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      });

      testWidgets('should show document icon', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentMenuSheet(
            showSheet: true,
            onDocumentTap: () {},
            onPhotosTap: () {},
          ),
        ));

        expect(find.byIcon(Icons.description_rounded), findsOneWidget);
      });
    });
  });
}
