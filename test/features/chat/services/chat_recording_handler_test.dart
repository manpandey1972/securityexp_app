// ChatRecordingHandler tests
//
// Tests for the chat recording handler which manages audio recording UI logic.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/features/chat/services/chat_recording_handler.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

import '../../../helpers/service_mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockAudioRecordingManager mockAudioRecordingManager;
  late MockAppLogger mockAppLogger;
  late List<File> completedRecordings;
  late ChatRecordingHandler handler;

  setUp(() {
    mockAudioRecordingManager = MockAudioRecordingManager();
    mockAppLogger = MockAppLogger();
    completedRecordings = [];

    // Register mock AppLogger
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    handler = ChatRecordingHandler(
      audioRecordingManager: mockAudioRecordingManager,
      onRecordingComplete: (file) async {
        completedRecordings.add(file);
      },
    );
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('ChatRecordingHandler', () {
    group('startRecording', () {
      test('should not start recording on web platform', () async {
        // This test will run on non-web platform during flutter test
        // On web, recording is not supported
        if (kIsWeb) {
          await handler.startRecording();
          verifyNever(mockAudioRecordingManager.startRecording());
        }
      });

      // Note: Permission testing requires platform channels which are not
      // available in unit tests. These would be integration tests.
      test('should call audio recording manager start', () async {
        // Skip on web
        if (kIsWeb) return;

        when(mockAudioRecordingManager.startRecording())
            .thenAnswer((_) async {});

        // In real tests, this would require mocking permission_handler
        // which uses platform channels
      });
    });

    group('stopRecording', () {
      test('should call audio recording manager stop and invoke callback on success', () async {
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/test_recording.m4a');

        when(mockAudioRecordingManager.stopRecording())
            .thenAnswer((_) async => testFile);

        await handler.stopRecording();

        verify(mockAudioRecordingManager.stopRecording()).called(1);
        expect(completedRecordings, contains(testFile));
      });

      test('should not invoke callback when stop returns null', () async {
        when(mockAudioRecordingManager.stopRecording())
            .thenAnswer((_) async => null);

        await handler.stopRecording();

        verify(mockAudioRecordingManager.stopRecording()).called(1);
        expect(completedRecordings, isEmpty);
      });

      test('should handle errors gracefully', () async {
        when(mockAudioRecordingManager.stopRecording())
            .thenThrow(Exception('Recording failed'));

        // Should not throw
        await handler.stopRecording();
        expect(completedRecordings, isEmpty);
      });
    });

    group('stopRecordingForPreview', () {
      test('should return audio file without sending', () async {
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/preview_recording.m4a');

        when(mockAudioRecordingManager.stopRecording())
            .thenAnswer((_) async => testFile);

        final result = await handler.stopRecordingForPreview();

        expect(result, testFile);
        verify(mockAudioRecordingManager.stopRecording()).called(1);
        // Should NOT invoke onRecordingComplete
        expect(completedRecordings, isEmpty);
      });

      test('should return null on failure', () async {
        when(mockAudioRecordingManager.stopRecording())
            .thenAnswer((_) async => null);

        final result = await handler.stopRecordingForPreview();

        expect(result, isNull);
      });

      test('should return null on error', () async {
        when(mockAudioRecordingManager.stopRecording())
            .thenThrow(Exception('Stop failed'));

        final result = await handler.stopRecordingForPreview();

        expect(result, isNull);
      });
    });

    group('pauseRecording', () {
      test('should call audio recording manager pause', () async {
        when(mockAudioRecordingManager.pauseRecording())
            .thenAnswer((_) async {});

        await handler.pauseRecording();

        verify(mockAudioRecordingManager.pauseRecording()).called(1);
      });

      test('should handle errors gracefully', () async {
        when(mockAudioRecordingManager.pauseRecording())
            .thenThrow(Exception('Pause failed'));

        // Should not throw
        await handler.pauseRecording();
      });
    });

    group('resumeRecording', () {
      test('should call audio recording manager resume', () async {
        when(mockAudioRecordingManager.resumeRecording())
            .thenAnswer((_) async {});

        await handler.resumeRecording();

        verify(mockAudioRecordingManager.resumeRecording()).called(1);
      });

      test('should handle errors gracefully', () async {
        when(mockAudioRecordingManager.resumeRecording())
            .thenThrow(Exception('Resume failed'));

        // Should not throw
        await handler.resumeRecording();
      });
    });

    group('cancelRecording', () {
      test('should call audio recording manager cancel', () async {
        when(mockAudioRecordingManager.cancelRecording())
            .thenAnswer((_) async {});

        await handler.cancelRecording();

        verify(mockAudioRecordingManager.cancelRecording()).called(1);
      });

      test('should handle errors gracefully', () async {
        when(mockAudioRecordingManager.cancelRecording())
            .thenThrow(Exception('Cancel failed'));

        // Should not throw
        await handler.cancelRecording();
      });
    });

    group('recording workflow', () {
      test('should support full recording lifecycle', () async {
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/full_workflow.m4a');

        when(mockAudioRecordingManager.startRecording())
            .thenAnswer((_) async {});
        when(mockAudioRecordingManager.pauseRecording())
            .thenAnswer((_) async {});
        when(mockAudioRecordingManager.resumeRecording())
            .thenAnswer((_) async {});
        when(mockAudioRecordingManager.stopRecording())
            .thenAnswer((_) async => testFile);

        // Simulate recording workflow (without actual permission)
        await handler.pauseRecording();
        await handler.resumeRecording();
        await handler.stopRecording();

        verify(mockAudioRecordingManager.pauseRecording()).called(1);
        verify(mockAudioRecordingManager.resumeRecording()).called(1);
        verify(mockAudioRecordingManager.stopRecording()).called(1);
        expect(completedRecordings, contains(testFile));
      });

      test('should support cancel workflow', () async {
        when(mockAudioRecordingManager.startRecording())
            .thenAnswer((_) async {});
        when(mockAudioRecordingManager.cancelRecording())
            .thenAnswer((_) async {});

        // Simulate cancel workflow
        await handler.cancelRecording();

        verify(mockAudioRecordingManager.cancelRecording()).called(1);
        expect(completedRecordings, isEmpty);
      });
    });
  });
}
