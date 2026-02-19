import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/chat/widgets/document_message_bubble.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  group('DocumentMessageBubble', () {
    group('rendering', () {
      testWidgets('should display file name', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.pdf',
          ),
        ));

        expect(find.text('report.pdf'), findsOneWidget);
      });

      testWidgets('should display file size when provided', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.pdf',
            fileSize: '2.5 MB',
          ),
        ));

        expect(find.text('2.5 MB'), findsOneWidget);
      });

      testWidgets('should show PDF icon for pdf files', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'document.pdf',
          ),
        ));

        expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      });

      testWidgets('should show text icon for txt files', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'readme.txt',
          ),
        ));

        expect(find.byIcon(Icons.description_rounded), findsOneWidget);
      });

      testWidgets('should show code icon for code files', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'main.dart',
          ),
        ));

        expect(find.byIcon(Icons.code_rounded), findsOneWidget);
      });

      testWidgets('should show article icon for doc files', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'thesis.docx',
          ),
        ));

        expect(find.byIcon(Icons.article_rounded), findsOneWidget);
      });

      testWidgets('should show table icon for xls files', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'data.xlsx',
          ),
        ));

        expect(find.byIcon(Icons.table_chart_rounded), findsOneWidget);
      });

      testWidgets('should show slideshow icon for ppt files', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'slides.pptx',
          ),
        ));

        expect(find.byIcon(Icons.slideshow_rounded), findsOneWidget);
      });

      testWidgets('should show generic file icon for unknown extensions', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'archive.zip',
          ),
        ));

        expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
      });

      testWidgets('should display file type label for PDF', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.pdf',
          ),
        ));

        expect(find.text('PDF'), findsOneWidget);
      });

      testWidgets('should display file type label for Word', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.docx',
          ),
        ));

        expect(find.text('Word'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('should call onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildTestableWidget(
          DocumentMessageBubble(
            fileName: 'report.pdf',
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(GestureDetector).first);
        expect(tapped, isTrue);
      });

      testWidgets('should show download button when onDownload provided', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          DocumentMessageBubble(
            fileName: 'report.pdf',
            onDownload: () {},
          ),
        ));

        expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      });

      testWidgets('should call onDownload when download tapped', (tester) async {
        var downloaded = false;
        await tester.pumpWidget(buildTestableWidget(
          DocumentMessageBubble(
            fileName: 'report.pdf',
            onDownload: () => downloaded = true,
          ),
        ));

        await tester.tap(find.byIcon(Icons.download_rounded));
        expect(downloaded, isTrue);
      });
    });

    group('download progress', () {
      testWidgets('should show progress indicator when downloading', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.pdf',
            isDownloading: true,
            downloadProgress: 0.5,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
      });

      testWidgets('should not show download button when downloading', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          DocumentMessageBubble(
            fileName: 'report.pdf',
            isDownloading: true,
            downloadProgress: 0.3,
            onDownload: () {},
          ),
        ));

        expect(find.byIcon(Icons.download_rounded), findsNothing);
      });
    });

    group('fromMe styling', () {
      testWidgets('should render correctly for sent messages', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.pdf',
            fromMe: true,
          ),
        ));

        expect(find.byType(DocumentMessageBubble), findsOneWidget);
      });

      testWidgets('should render correctly for received messages', (tester) async {
        await tester.pumpWidget(buildTestableWidget(
          const DocumentMessageBubble(
            fileName: 'report.pdf',
            fromMe: false,
          ),
        ));

        expect(find.byType(DocumentMessageBubble), findsOneWidget);
      });
    });
  });
}
