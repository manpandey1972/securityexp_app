import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/features/chat/services/chat_media_handler.dart';

import '../helpers/service_mocks.mocks.dart';

void main() {
  late MockUploadManager mockUploadManager;
  late ChatMediaHandler handler;
  late bool clearReplyCalled;
  late Message? replyMessage;

  const testRoomId = 'test-room-123';
  const testUploadId = 'upload_123_0';

  setUp(() {
    mockUploadManager = MockUploadManager();
    clearReplyCalled = false;
    replyMessage = null;

    handler = ChatMediaHandler(
      uploadManager: mockUploadManager,
      roomId: testRoomId,
      getReplyToMessage: () => replyMessage,
      clearReply: () => clearReplyCalled = true,
    );

    // Default stub for startUpload
    when(
      mockUploadManager.startUpload(
        roomId: anyNamed('roomId'),
        filePath: anyNamed('filePath'),
        bytes: anyNamed('bytes'),
        filename: anyNamed('filename'),
        replyToMessage: anyNamed('replyToMessage'),
      ),
    ).thenAnswer((_) async => testUploadId);
  });

  group('ChatMediaHandler', () {
    group('handleAudioFile', () {
      test('delegates to UploadManager.startUpload with correct params',
          () async {
        final audioFile = File('/tmp/recording.m4a');

        await handler.handleAudioFile(audioFile: audioFile);

        verify(
          mockUploadManager.startUpload(
            roomId: testRoomId,
            filePath: '/tmp/recording.m4a',
            bytes: null,
            filename: 'recording.m4a',
            replyToMessage: null,
          ),
        ).called(1);
      });

      test('calls clearReply after upload starts', () async {
        final audioFile = File('/tmp/recording.m4a');

        await handler.handleAudioFile(audioFile: audioFile);

        expect(clearReplyCalled, isTrue);
      });

      test('passes reply message to startUpload when replying', () async {
        final mockMessage = Message(
          id: 'msg-1',
          senderId: 'user-1',
          text: 'original message',
          type: MessageType.text,
          timestamp: Timestamp.now(),
        );
        replyMessage = mockMessage;

        final audioFile = File('/tmp/voice.m4a');
        await handler.handleAudioFile(audioFile: audioFile);

        verify(
          mockUploadManager.startUpload(
            roomId: testRoomId,
            filePath: '/tmp/voice.m4a',
            bytes: null,
            filename: 'voice.m4a',
            replyToMessage: mockMessage,
          ),
        ).called(1);
      });

      test('extracts filename from file path', () async {
        final audioFile = File('/path/to/nested/audio_file.mp3');

        await handler.handleAudioFile(audioFile: audioFile);

        verify(
          mockUploadManager.startUpload(
            roomId: testRoomId,
            filePath: '/path/to/nested/audio_file.mp3',
            bytes: null,
            filename: 'audio_file.mp3',
            replyToMessage: null,
          ),
        ).called(1);
      });
    });

    group('handleCameraCapture', () {
      testWidgets('delegates to UploadManager.startUpload with bytes',
          (tester) async {
        await tester.pumpWidget(Builder(
          builder: (context) {
            // Schedule the test action after the widget is built
            Future.microtask(() async {
              final bytes = [1, 2, 3, 4, 5];
              const filename = 'photo_2025.jpg';

              await handler.handleCameraCapture(
                context: context,
                filePath: '/tmp/photo_2025.jpg',
                bytes: bytes,
                filename: filename,
              );

              verify(
                mockUploadManager.startUpload(
                  roomId: testRoomId,
                  filePath: '/tmp/photo_2025.jpg',
                  bytes: Uint8List.fromList(bytes),
                  filename: filename,
                  replyToMessage: null,
                ),
              ).called(1);
            });
            return const SizedBox.shrink();
          },
        ));
        await tester.pumpAndSettle();
      });

      testWidgets('calls clearReply after camera capture upload',
          (tester) async {
        await tester.pumpWidget(Builder(
          builder: (context) {
            Future.microtask(() async {
              await handler.handleCameraCapture(
                context: context,
                filePath: '/tmp/photo.jpg',
                bytes: [0, 1, 2],
                filename: 'photo.jpg',
              );

              expect(clearReplyCalled, isTrue);
            });
            return const SizedBox.shrink();
          },
        ));
        await tester.pumpAndSettle();
      });

      testWidgets('passes null filePath when not available', (tester) async {
        await tester.pumpWidget(Builder(
          builder: (context) {
            Future.microtask(() async {
              const filename = 'photo.jpg';
              final bytes = [10, 20, 30];

              await handler.handleCameraCapture(
                context: context,
                filePath: null,
                bytes: bytes,
                filename: filename,
              );

              verify(
                mockUploadManager.startUpload(
                  roomId: testRoomId,
                  filePath: null,
                  bytes: Uint8List.fromList(bytes),
                  filename: filename,
                  replyToMessage: null,
                ),
              ).called(1);
            });
            return const SizedBox.shrink();
          },
        ));
        await tester.pumpAndSettle();
      });

      testWidgets('passes reply message when replying with camera capture',
          (tester) async {
        final mockMessage = Message(
          id: 'msg-reply',
          senderId: 'user-1',
          text: 'reply to this',
          type: MessageType.text,
          timestamp: Timestamp.now(),
        );
        replyMessage = mockMessage;

        await tester.pumpWidget(Builder(
          builder: (context) {
            Future.microtask(() async {
              await handler.handleCameraCapture(
                context: context,
                filePath: '/tmp/cam.jpg',
                bytes: [1, 2],
                filename: 'cam.jpg',
              );

              verify(
                mockUploadManager.startUpload(
                  roomId: testRoomId,
                  filePath: '/tmp/cam.jpg',
                  bytes: Uint8List.fromList([1, 2]),
                  filename: 'cam.jpg',
                  replyToMessage: mockMessage,
                ),
              ).called(1);
            });
            return const SizedBox.shrink();
          },
        ));
        await tester.pumpAndSettle();
      });
    });

    group('constructor', () {
      test('accepts injected UploadManager', () async {
        // Verify the handler uses the injected mock (not the service locator)
        final audioFile = File('/tmp/test.m4a');
        await handler.handleAudioFile(audioFile: audioFile);

        verify(
          mockUploadManager.startUpload(
            roomId: anyNamed('roomId'),
            filePath: anyNamed('filePath'),
            bytes: anyNamed('bytes'),
            filename: anyNamed('filename'),
            replyToMessage: anyNamed('replyToMessage'),
          ),
        ).called(1);
      });

      test('uses provided roomId for all uploads', () async {
        final customHandler = ChatMediaHandler(
          uploadManager: mockUploadManager,
          roomId: 'custom-room-456',
          getReplyToMessage: () => null,
          clearReply: () {},
        );

        await customHandler.handleAudioFile(
          audioFile: File('/tmp/test.m4a'),
        );

        verify(
          mockUploadManager.startUpload(
            roomId: 'custom-room-456',
            filePath: anyNamed('filePath'),
            bytes: anyNamed('bytes'),
            filename: anyNamed('filename'),
            replyToMessage: anyNamed('replyToMessage'),
          ),
        ).called(1);
      });
    });

    group('clearReply behavior', () {
      test('clearReply is called even when replyMessage is null', () async {
        replyMessage = null;

        await handler.handleAudioFile(audioFile: File('/tmp/test.m4a'));

        expect(clearReplyCalled, isTrue);
      });

      test('clearReply is called after startUpload completes', () async {
        var uploadStarted = false;

        when(
          mockUploadManager.startUpload(
            roomId: anyNamed('roomId'),
            filePath: anyNamed('filePath'),
            bytes: anyNamed('bytes'),
            filename: anyNamed('filename'),
            replyToMessage: anyNamed('replyToMessage'),
          ),
        ).thenAnswer((_) async {
          uploadStarted = true;
          return testUploadId;
        });

        // Track ordering: clearReply should happen after startUpload
        clearReplyCalled = false;
        handler = ChatMediaHandler(
          uploadManager: mockUploadManager,
          roomId: testRoomId,
          getReplyToMessage: () => replyMessage,
          clearReply: () {
            expect(uploadStarted, isTrue,
                reason: 'clearReply should be called after startUpload');
            clearReplyCalled = true;
          },
        );

        await handler.handleAudioFile(audioFile: File('/tmp/test.m4a'));

        expect(clearReplyCalled, isTrue);
      });
    });
  });
}
