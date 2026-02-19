import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/data/models/upload_state.dart';
import 'package:greenhive_app/data/models/models.dart';

void main() {
  group('UploadStatus Enum', () {
    test('should have all expected values', () {
      expect(UploadStatus.values.length, 4);
      expect(UploadStatus.values, contains(UploadStatus.uploading));
      expect(UploadStatus.values, contains(UploadStatus.completed));
      expect(UploadStatus.values, contains(UploadStatus.failed));
      expect(UploadStatus.values, contains(UploadStatus.cancelled));
    });
  });

  group('UploadState', () {
    late DateTime testStartTime;

    setUp(() {
      testStartTime = DateTime.now();
    });

    group('Constructor', () {
      test('should create UploadState with all required fields', () {
        final state = UploadState(
          id: 'upload_1',
          roomId: 'room_123',
          filename: 'photo.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.id, 'upload_1');
        expect(state.roomId, 'room_123');
        expect(state.filename, 'photo.jpg');
        expect(state.type, MessageType.image);
        expect(state.status, UploadStatus.uploading);
        expect(state.progress, 0.5);
        expect(state.startedAt, testStartTime);
        expect(state.error, isNull);
        expect(state.replyToMessageId, isNull);
        expect(state.replyToMessage, isNull);
      });

      test('should create UploadState with optional fields', () {
        final replyMessage = Message(
          id: 'msg_123',
          senderId: 'user_1',
          type: MessageType.text,
          text: 'Original message',
          timestamp: Timestamp.now(),
        );

        final state = UploadState(
          id: 'upload_2',
          roomId: 'room_456',
          filename: 'video.mp4',
          type: MessageType.video,
          status: UploadStatus.failed,
          progress: 0.75,
          error: 'Network error',
          replyToMessageId: 'msg_123',
          replyToMessage: replyMessage,
          startedAt: testStartTime,
        );

        expect(state.error, 'Network error');
        expect(state.replyToMessageId, 'msg_123');
        expect(state.replyToMessage, replyMessage);
      });
    });

    group('copyWith', () {
      test('should create copy with updated status', () {
        final original = UploadState(
          id: 'upload_3',
          roomId: 'room_789',
          filename: 'audio.m4a',
          type: MessageType.audio,
          status: UploadStatus.uploading,
          progress: 0.25,
          startedAt: testStartTime,
        );

        final updated = original.copyWith(
          status: UploadStatus.completed,
          progress: 1.0,
        );

        expect(updated.id, original.id);
        expect(updated.roomId, original.roomId);
        expect(updated.filename, original.filename);
        expect(updated.status, UploadStatus.completed);
        expect(updated.progress, 1.0);
      });

      test('should create copy with error', () {
        final original = UploadState(
          id: 'upload_4',
          roomId: 'room_abc',
          filename: 'document.pdf',
          type: MessageType.doc,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        final updated = original.copyWith(
          status: UploadStatus.failed,
          error: 'Upload failed: timeout',
        );

        expect(updated.status, UploadStatus.failed);
        expect(updated.error, 'Upload failed: timeout');
        expect(updated.progress, 0.5); // Progress unchanged
      });

      test('should create copy with reply information', () {
        final original = UploadState(
          id: 'upload_5',
          roomId: 'room_def',
          filename: 'image.png',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.0,
          startedAt: testStartTime,
        );

        final replyMessage = Message(
          id: 'reply_msg',
          senderId: 'user_2',
          text: 'Reply to this',
          timestamp: Timestamp.now(),
        );

        final updated = original.copyWith(
          replyToMessageId: 'reply_msg',
          replyToMessage: replyMessage,
        );

        expect(updated.replyToMessageId, 'reply_msg');
        expect(updated.replyToMessage?.text, 'Reply to this');
      });

      test('should preserve original values when no update provided', () {
        final original = UploadState(
          id: 'upload_6',
          roomId: 'room_ghi',
          filename: 'file.txt',
          type: MessageType.doc,
          status: UploadStatus.uploading,
          progress: 0.33,
          error: 'Some error',
          startedAt: testStartTime,
        );

        final updated = original.copyWith();

        expect(updated.id, original.id);
        expect(updated.roomId, original.roomId);
        expect(updated.filename, original.filename);
        expect(updated.type, original.type);
        expect(updated.status, original.status);
        expect(updated.progress, original.progress);
        expect(updated.error, original.error);
        expect(updated.startedAt, original.startedAt);
      });
    });

    group('isActive', () {
      test('should return true when status is uploading', () {
        final state = UploadState(
          id: 'active_upload',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.isActive, isTrue);
      });

      test('should return false when status is completed', () {
        final state = UploadState(
          id: 'completed_upload',
          roomId: 'room_2',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.completed,
          progress: 1.0,
          startedAt: testStartTime,
        );

        expect(state.isActive, isFalse);
      });

      test('should return false when status is failed', () {
        final state = UploadState(
          id: 'failed_upload',
          roomId: 'room_3',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.failed,
          progress: 0.5,
          error: 'Error',
          startedAt: testStartTime,
        );

        expect(state.isActive, isFalse);
      });

      test('should return false when status is cancelled', () {
        final state = UploadState(
          id: 'cancelled_upload',
          roomId: 'room_4',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.cancelled,
          progress: 0.25,
          startedAt: testStartTime,
        );

        expect(state.isActive, isFalse);
      });
    });

    group('statusText', () {
      test('should return progress text when uploading', () {
        final state = UploadState(
          id: 'upload_progress_1',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.statusText, 'Uploading 50%');
      });

      test('should return correct progress percentage for various values', () {
        final state0 = UploadState(
          id: 'upload_0',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.0,
          startedAt: testStartTime,
        );
        expect(state0.statusText, 'Uploading 0%');

        final state25 = state0.copyWith(progress: 0.25);
        expect(state25.statusText, 'Uploading 25%');

        final state75 = state0.copyWith(progress: 0.75);
        expect(state75.statusText, 'Uploading 75%');

        final state99 = state0.copyWith(progress: 0.99);
        expect(state99.statusText, 'Uploading 99%');

        final state100 = state0.copyWith(progress: 1.0);
        expect(state100.statusText, 'Uploading 100%');
      });

      test('should return "Completed" when status is completed', () {
        final state = UploadState(
          id: 'upload_complete',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.completed,
          progress: 1.0,
          startedAt: testStartTime,
        );

        expect(state.statusText, 'Completed');
      });

      test('should return "Failed" when status is failed', () {
        final state = UploadState(
          id: 'upload_failed',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.failed,
          progress: 0.5,
          error: 'Network error',
          startedAt: testStartTime,
        );

        expect(state.statusText, 'Failed');
      });

      test('should return "Cancelled" when status is cancelled', () {
        final state = UploadState(
          id: 'upload_cancelled',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.cancelled,
          progress: 0.3,
          startedAt: testStartTime,
        );

        expect(state.statusText, 'Cancelled');
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        final state = UploadState(
          id: 'upload_tostring',
          roomId: 'room_1',
          filename: 'document.pdf',
          type: MessageType.doc,
          status: UploadStatus.uploading,
          progress: 0.67,
          startedAt: testStartTime,
        );

        final str = state.toString();

        expect(str, contains('upload_tostring'));
        expect(str, contains('document.pdf'));
        expect(str, contains('uploading'));
        expect(str, contains('67%'));
      });
    });

    group('Message Types', () {
      test('should handle image upload state', () {
        final state = UploadState(
          id: 'img_upload',
          roomId: 'room_1',
          filename: 'photo.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.type, MessageType.image);
      });

      test('should handle video upload state', () {
        final state = UploadState(
          id: 'vid_upload',
          roomId: 'room_1',
          filename: 'video.mp4',
          type: MessageType.video,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.type, MessageType.video);
      });

      test('should handle audio upload state', () {
        final state = UploadState(
          id: 'aud_upload',
          roomId: 'room_1',
          filename: 'voice.m4a',
          type: MessageType.audio,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.type, MessageType.audio);
      });

      test('should handle document upload state', () {
        final state = UploadState(
          id: 'doc_upload',
          roomId: 'room_1',
          filename: 'report.pdf',
          type: MessageType.doc,
          status: UploadStatus.uploading,
          progress: 0.5,
          startedAt: testStartTime,
        );

        expect(state.type, MessageType.doc);
      });
    });

    group('Progress Boundaries', () {
      test('should handle 0% progress', () {
        final state = UploadState(
          id: 'progress_0',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.0,
          startedAt: testStartTime,
        );

        expect(state.progress, 0.0);
        expect(state.statusText, 'Uploading 0%');
      });

      test('should handle 100% progress', () {
        final state = UploadState(
          id: 'progress_100',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 1.0,
          startedAt: testStartTime,
        );

        expect(state.progress, 1.0);
        expect(state.statusText, 'Uploading 100%');
      });

      test('should handle fractional progress', () {
        final state = UploadState(
          id: 'progress_frac',
          roomId: 'room_1',
          filename: 'file.jpg',
          type: MessageType.image,
          status: UploadStatus.uploading,
          progress: 0.333,
          startedAt: testStartTime,
        );

        expect(state.statusText, 'Uploading 33%');
      });
    });
  });
}
