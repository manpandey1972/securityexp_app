import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/support/data/models/pending_attachment.dart';
import 'package:greenhive_app/features/support/widgets/attachment_picker.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('AttachmentPicker', () {
    PendingAttachment createAttachment({
      String filename = 'test.pdf',
      Uint8List? bytes,
    }) {
      return PendingAttachment(
        filename: filename,
        bytes: bytes ?? Uint8List.fromList([1, 2, 3]),
      );
    }

    group('rendering', () {
      testWidgets('should display Attachments header', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: const [],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.text('Attachments'), findsOneWidget);
      });

      testWidgets('should display attachment count', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: [createAttachment()],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.text('1/5'), findsOneWidget);
      });

      testWidgets('should display help text', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: const [],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.text('Max 10MB per file • Images, PDF, or text files'), findsOneWidget);
      });

      testWidgets('should display attachment items', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: [
              createAttachment(filename: 'report.pdf'),
              createAttachment(filename: 'image.jpg'),
            ],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.text('report.pdf'), findsOneWidget);
        expect(find.text('image.jpg'), findsOneWidget);
      });
    });

    group('add buttons', () {
      testWidgets('should show Gallery and File buttons when can add more', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: const [],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.text('Gallery'), findsOneWidget);
        expect(find.text('File'), findsOneWidget);
      });

      testWidgets('should hide add buttons when at max attachments', (tester) async {
        final attachments = List.generate(
          5,
          (i) => createAttachment(filename: 'file_$i.pdf'),
        );

        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: attachments,
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.text('Gallery'), findsNothing);
        expect(find.text('File'), findsNothing);
      });

      testWidgets('should call onPickImage when Gallery tapped', (tester) async {
        var imagePicked = false;
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: const [],
            onPickImage: () => imagePicked = true,
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        await tester.tap(find.text('Gallery'));
        await tester.pumpAndSettle();
        expect(imagePicked, isTrue);
      });

      testWidgets('should call onPickFile when File tapped', (tester) async {
        var filePicked = false;
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: const [],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () => filePicked = true,
            onRemove: (_) {},
          ),
        ));

        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();
        expect(filePicked, isTrue);
      });
    });

    group('remove attachment', () {
      testWidgets('should show remove button for each attachment', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: [createAttachment(filename: 'file.pdf')],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
          ),
        ));

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('should call onRemove with index when remove tapped', (tester) async {
        int? removedIndex;
        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: [createAttachment(filename: 'file.pdf')],
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (index) => removedIndex = index,
          ),
        ));

        await tester.tap(find.byIcon(Icons.close));
        expect(removedIndex, equals(0));
      });
    });

    group('max attachments', () {
      testWidgets('should respect custom maxAttachments', (tester) async {
        final attachments = List.generate(
          3,
          (i) => createAttachment(filename: 'file_$i.pdf'),
        );

        await tester.pumpWidget(buildTestableWidget(
          AttachmentPicker(
            attachments: attachments,
            onPickImage: () {},
            onTakePhoto: () {},
            onPickFile: () {},
            onRemove: (_) {},
            maxAttachments: 3,
          ),
        ));

        expect(find.text('3/3'), findsOneWidget);
        expect(find.text('Gallery'), findsNothing);
      });
    });
  });
}
