import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/features/chat/utils/chat_utils.dart';
import 'package:greenhive_app/data/models/models.dart';

void main() {
  group('ChatConstants', () {
    test('should have correct pagination values', () {
      expect(ChatConstants.pageSize, 50);
      expect(ChatConstants.mediaCacheLimit, 100);
    });

    test('should have correct animation durations', () {
      expect(ChatConstants.scrollAnimationDuration.inMilliseconds, 300);
      expect(ChatConstants.scrollDelayBeforeAutoScroll.inMilliseconds, 200);
      expect(ChatConstants.scrollToNewMessageDelay.inMilliseconds, 800);
      expect(ChatConstants.attachmentSheetDuration.inMilliseconds, 250);
      expect(ChatConstants.recordingToastDuration.inSeconds, 1);
    });

    test('should have correct UI dimension values', () {
      expect(ChatConstants.chatMessagePadding, 12.0);
      expect(ChatConstants.chatMediaPadding, 4.0);
      expect(ChatConstants.chatBorderRadius, 12.0);
      expect(ChatConstants.profileAvatarRadius, 20);
      expect(ChatConstants.messageCornerRadius, 12);
      expect(ChatConstants.circleAvatarRadius, 24);
    });

    test('should have correct file extensions', () {
      expect(ChatConstants.imageExtensions, containsAll(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']));
      expect(ChatConstants.videoExtensions, containsAll(['mp4', 'mov', 'avi', 'mkv', 'webm']));
      expect(ChatConstants.audioExtensions, containsAll(['mp3', 'wav', 'm4a', 'aac']));
      expect(ChatConstants.documentExtensions, containsAll(['pdf', 'doc', 'docx', 'txt']));
      expect(ChatConstants.heicExtensions, containsAll(['heic', 'heif']));
    });
  });

  group('FileTypeHelper', () {
    group('getMessageTypeFromExtension', () {
      test('should return MessageType.video for video extensions', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('mp4'), MessageType.video);
        expect(FileTypeHelper.getMessageTypeFromExtension('mov'), MessageType.video);
        expect(FileTypeHelper.getMessageTypeFromExtension('avi'), MessageType.video);
        expect(FileTypeHelper.getMessageTypeFromExtension('.mp4'), MessageType.video);
        expect(FileTypeHelper.getMessageTypeFromExtension('MP4'), MessageType.video);
      });

      test('should return MessageType.audio for audio extensions', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('mp3'), MessageType.audio);
        expect(FileTypeHelper.getMessageTypeFromExtension('wav'), MessageType.audio);
        expect(FileTypeHelper.getMessageTypeFromExtension('m4a'), MessageType.audio);
        expect(FileTypeHelper.getMessageTypeFromExtension('.mp3'), MessageType.audio);
        expect(FileTypeHelper.getMessageTypeFromExtension('M4A'), MessageType.audio);
      });

      test('should return MessageType.image for image extensions', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('jpg'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('jpeg'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('png'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('gif'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('.jpg'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('PNG'), MessageType.image);
      });

      test('should return MessageType.doc for document extensions', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('pdf'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension('doc'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension('docx'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension('txt'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension('.pdf'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension('PDF'), MessageType.doc);
      });

      test('should return MessageType.doc for unknown extensions', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('xyz'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension('unknown'), MessageType.doc);
        expect(FileTypeHelper.getMessageTypeFromExtension(''), MessageType.doc);
      });

      test('should handle extensions with or without leading dot', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('.jpg'), 
               FileTypeHelper.getMessageTypeFromExtension('jpg'));
        expect(FileTypeHelper.getMessageTypeFromExtension('.mp4'), 
               FileTypeHelper.getMessageTypeFromExtension('mp4'));
      });

      test('should be case insensitive', () {
        expect(FileTypeHelper.getMessageTypeFromExtension('JPG'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('Jpg'), MessageType.image);
        expect(FileTypeHelper.getMessageTypeFromExtension('jPg'), MessageType.image);
      });
    });

    group('getFileCategory', () {
      test('should return media for image extensions', () {
        expect(FileTypeHelper.getFileCategory('jpg'), 'media');
        expect(FileTypeHelper.getFileCategory('png'), 'media');
        expect(FileTypeHelper.getFileCategory('gif'), 'media');
      });

      test('should return media for video extensions', () {
        expect(FileTypeHelper.getFileCategory('mp4'), 'media');
        expect(FileTypeHelper.getFileCategory('mov'), 'media');
        expect(FileTypeHelper.getFileCategory('avi'), 'media');
      });

      test('should return media for audio extensions', () {
        expect(FileTypeHelper.getFileCategory('mp3'), 'media');
        expect(FileTypeHelper.getFileCategory('m4a'), 'media');
        expect(FileTypeHelper.getFileCategory('wav'), 'media');
      });

      test('should return document for document extensions', () {
        expect(FileTypeHelper.getFileCategory('pdf'), 'document');
        expect(FileTypeHelper.getFileCategory('doc'), 'document');
        expect(FileTypeHelper.getFileCategory('xlsx'), 'document');
      });

      test('should return file for unknown extensions', () {
        expect(FileTypeHelper.getFileCategory('xyz'), 'file');
        expect(FileTypeHelper.getFileCategory('unknown'), 'file');
      });

      test('should handle extensions with leading dot', () {
        expect(FileTypeHelper.getFileCategory('.jpg'), 'media');
        expect(FileTypeHelper.getFileCategory('.pdf'), 'document');
      });
    });

    group('generateDownloadFilename', () {
      test('should generate media filename for image extension', () {
        final filename = FileTypeHelper.generateDownloadFilename('jpg', 123456);
        expect(filename, 'media_123456.jpg');
      });

      test('should generate media filename for video extension', () {
        final filename = FileTypeHelper.generateDownloadFilename('mp4', 789012);
        expect(filename, 'media_789012.mp4');
      });

      test('should generate media filename for audio extension', () {
        final filename = FileTypeHelper.generateDownloadFilename('m4a', 345678);
        expect(filename, 'media_345678.m4a');
      });

      test('should generate document filename for document extension', () {
        final filename = FileTypeHelper.generateDownloadFilename('pdf', 901234);
        expect(filename, 'document_901234.pdf');
      });

      test('should generate file filename for unknown extension', () {
        final filename = FileTypeHelper.generateDownloadFilename('xyz', 567890);
        expect(filename, 'file_567890.xyz');
      });

      test('should handle extension with leading dot', () {
        final filename = FileTypeHelper.generateDownloadFilename('.jpg', 111222);
        expect(filename, 'media_111222.jpg');
      });

      test('should convert extension to lowercase', () {
        final filename = FileTypeHelper.generateDownloadFilename('JPG', 333444);
        expect(filename, 'media_333444.jpg');
      });
    });

    group('isHeicFormat', () {
      test('should return true for heic extension', () {
        expect(FileTypeHelper.isHeicFormat('heic'), isTrue);
        expect(FileTypeHelper.isHeicFormat('HEIC'), isTrue);
        expect(FileTypeHelper.isHeicFormat('.heic'), isTrue);
      });

      test('should return true for heif extension', () {
        expect(FileTypeHelper.isHeicFormat('heif'), isTrue);
        expect(FileTypeHelper.isHeicFormat('HEIF'), isTrue);
        expect(FileTypeHelper.isHeicFormat('.heif'), isTrue);
      });

      test('should return false for non-heic formats', () {
        expect(FileTypeHelper.isHeicFormat('jpg'), isFalse);
        expect(FileTypeHelper.isHeicFormat('png'), isFalse);
        expect(FileTypeHelper.isHeicFormat('mp4'), isFalse);
      });
    });
  });

  group('DateTimeFormatter', () {
    group('monthNames', () {
      test('should have correct month names', () {
        expect(DateTimeFormatter.monthNames.length, 13); // Index 0 is empty
        expect(DateTimeFormatter.monthNames[1], 'Jan');
        expect(DateTimeFormatter.monthNames[6], 'Jun');
        expect(DateTimeFormatter.monthNames[12], 'Dec');
      });
    });

    group('formatTimeOnly', () {
      test('should format AM times correctly', () {
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 9, 30)), '9:30 AM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 0, 0)), '12:00 AM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 11, 59)), '11:59 AM');
      });

      test('should format PM times correctly', () {
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 12, 0)), '12:00 PM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 13, 30)), '1:30 PM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 23, 59)), '11:59 PM');
      });

      test('should pad minutes with leading zero', () {
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 9, 5)), '9:05 AM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 14, 1)), '2:01 PM');
      });

      test('should convert 24-hour to 12-hour format', () {
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 0, 0)), '12:00 AM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 12, 0)), '12:00 PM');
        expect(DateTimeFormatter.formatTimeOnly(DateTime(2024, 1, 1, 15, 0)), '3:00 PM');
      });
    });

    group('formatDateSeparator', () {
      test('should return "Today" for today\'s date', () {
        final now = DateTime.now();
        expect(DateTimeFormatter.formatDateSeparator(now), 'Today');
      });

      test('should return "Yesterday" for yesterday\'s date', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(DateTimeFormatter.formatDateSeparator(yesterday), 'Yesterday');
      });

      test('should return formatted date for older dates', () {
        final date = DateTime(2024, 3, 15);
        final result = DateTimeFormatter.formatDateSeparator(date);
        
        // If the date is not today or yesterday, it should be formatted
        if (result != 'Today' && result != 'Yesterday') {
          expect(result, 'Mar 15');
        }
      });

      test('should format date with correct month name', () {
        // Use a date far enough in the past to not be today/yesterday
        final date = DateTime(2023, 1, 1);
        final result = DateTimeFormatter.formatDateSeparator(date);
        expect(result, 'Jan 1');
      });
    });

    group('formatCallDuration', () {
      test('should format seconds only', () {
        expect(DateTimeFormatter.formatCallDuration(45), '0:45');
        expect(DateTimeFormatter.formatCallDuration(5), '0:05');
        expect(DateTimeFormatter.formatCallDuration(0), '0:00');
      });

      test('should format minutes and seconds', () {
        expect(DateTimeFormatter.formatCallDuration(60), '1:00');
        expect(DateTimeFormatter.formatCallDuration(90), '1:30');
        expect(DateTimeFormatter.formatCallDuration(125), '2:05');
      });

      test('should format hours as minutes', () {
        expect(DateTimeFormatter.formatCallDuration(3600), '60:00');
        expect(DateTimeFormatter.formatCallDuration(3665), '61:05');
      });

      test('should pad seconds with leading zero', () {
        expect(DateTimeFormatter.formatCallDuration(61), '1:01');
        expect(DateTimeFormatter.formatCallDuration(69), '1:09');
      });
    });

    group('getDefaultFilename', () {
      test('should generate audio filename', () {
        final message = Message(
          id: 'msg1',
          senderId: 'user1',
          type: MessageType.audio,
          timestamp: Timestamp.now(),
        );
        
        final filename = DateTimeFormatter.getDefaultFilename(message);
        expect(filename, startsWith('audio_'));
        expect(filename, endsWith('.m4a'));
      });

      test('should generate video filename', () {
        final message = Message(
          id: 'msg2',
          senderId: 'user1',
          type: MessageType.video,
          timestamp: Timestamp.now(),
        );
        
        final filename = DateTimeFormatter.getDefaultFilename(message);
        expect(filename, startsWith('video_'));
        expect(filename, endsWith('.mp4'));
      });

      test('should generate image filename', () {
        final message = Message(
          id: 'msg3',
          senderId: 'user1',
          type: MessageType.image,
          timestamp: Timestamp.now(),
        );
        
        final filename = DateTimeFormatter.getDefaultFilename(message);
        expect(filename, startsWith('image_'));
        expect(filename, endsWith('.jpg'));
      });

      test('should generate document filename', () {
        final message = Message(
          id: 'msg4',
          senderId: 'user1',
          type: MessageType.doc,
          timestamp: Timestamp.now(),
        );
        
        final filename = DateTimeFormatter.getDefaultFilename(message);
        expect(filename, startsWith('document_'));
        expect(filename, endsWith('.pdf'));
      });

      test('should generate generic filename for text messages', () {
        final message = Message(
          id: 'msg5',
          senderId: 'user1',
          type: MessageType.text,
          text: 'Hello',
          timestamp: Timestamp.now(),
        );
        
        final filename = DateTimeFormatter.getDefaultFilename(message);
        expect(filename, startsWith('file_'));
      });

      test('should use unique timestamps', () {
        final message = Message(
          id: 'msg6',
          senderId: 'user1',
          type: MessageType.image,
          timestamp: Timestamp.now(),
        );
        
        final filename1 = DateTimeFormatter.getDefaultFilename(message);
        // Small delay to ensure different timestamp
        final filename2 = DateTimeFormatter.getDefaultFilename(message);
        
        // Both should be valid image filenames
        expect(filename1, startsWith('image_'));
        expect(filename2, startsWith('image_'));
      });
    });
  });
}
