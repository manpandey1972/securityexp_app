import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/features/chat/widgets/uploading_message.dart';

void main() {
  group('UploadingMessageWidget', () {
    Widget buildWidget({
      String filename = 'test.jpg',
      MessageType type = MessageType.image,
      double progress = 0.5,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: UploadingMessageWidget(
            filename: filename,
            type: type,
            progress: progress,
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('should display filename', (tester) async {
        await tester.pumpWidget(buildWidget(filename: 'photo.jpg'));

        expect(find.text('photo.jpg'), findsOneWidget);
      });

      testWidgets('should display progress percentage', (tester) async {
        await tester.pumpWidget(buildWidget(progress: 0.75));

        expect(find.text('Uploading 75%'), findsOneWidget);
      });

      testWidgets('should show progress bar', (tester) async {
        await tester.pumpWidget(buildWidget(progress: 0.5));

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('should display 0% for zero progress', (tester) async {
        await tester.pumpWidget(buildWidget(progress: 0.0));

        expect(find.text('Uploading 0%'), findsOneWidget);
      });

      testWidgets('should display 100% for complete progress', (tester) async {
        await tester.pumpWidget(buildWidget(progress: 1.0));

        expect(find.text('Uploading 100%'), findsOneWidget);
      });
    });

    group('icons by type', () {
      testWidgets('should show image icon for image type', (tester) async {
        await tester.pumpWidget(buildWidget(type: MessageType.image));

        expect(find.byIcon(Icons.image), findsOneWidget);
      });

      testWidgets('should show video icon for video type', (tester) async {
        await tester.pumpWidget(buildWidget(type: MessageType.video));

        expect(find.byIcon(Icons.videocam), findsOneWidget);
      });

      testWidgets('should show audio icon for audio type', (tester) async {
        await tester.pumpWidget(buildWidget(type: MessageType.audio));

        expect(find.byIcon(Icons.audiotrack), findsOneWidget);
      });

      testWidgets('should show pdf icon for PDF document', (tester) async {
        await tester.pumpWidget(buildWidget(
          type: MessageType.doc,
          filename: 'document.pdf',
        ));

        expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      });

      testWidgets('should show text icon for txt document', (tester) async {
        await tester.pumpWidget(buildWidget(
          type: MessageType.doc,
          filename: 'readme.txt',
        ));

        expect(find.byIcon(Icons.description_rounded), findsOneWidget);
      });

      testWidgets('should show code icon for code files', (tester) async {
        await tester.pumpWidget(buildWidget(
          type: MessageType.doc,
          filename: 'main.dart',
        ));

        expect(find.byIcon(Icons.code_rounded), findsOneWidget);
      });

      testWidgets('should show generic icon for unknown doc type', (tester) async {
        await tester.pumpWidget(buildWidget(
          type: MessageType.doc,
          filename: 'data.zip',
        ));

        expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
      });

      testWidgets('should show image icon for text type (default)', (tester) async {
        await tester.pumpWidget(buildWidget(type: MessageType.text));

        expect(find.byIcon(Icons.image), findsOneWidget);
      });
    });
  });
}
