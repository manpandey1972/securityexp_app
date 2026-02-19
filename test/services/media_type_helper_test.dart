// MediaTypeHelper tests
//
// Tests for the media type helper service which categorizes files by extension.

import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/shared/services/media_type_helper.dart';

void main() {
  group('MediaTypeHelper', () {
    group('getExtension', () {
      test('should extract extension from file path', () {
        expect(MediaTypeHelper.getExtension('photo.jpg'), 'jpg');
        expect(MediaTypeHelper.getExtension('document.pdf'), 'pdf');
        expect(MediaTypeHelper.getExtension('video.mp4'), 'mp4');
      });

      test('should return lowercase extension', () {
        expect(MediaTypeHelper.getExtension('photo.JPG'), 'jpg');
        expect(MediaTypeHelper.getExtension('document.PDF'), 'pdf');
        expect(MediaTypeHelper.getExtension('video.MP4'), 'mp4');
      });

      test('should handle paths with multiple dots', () {
        expect(MediaTypeHelper.getExtension('my.photo.jpg'), 'jpg');
        expect(MediaTypeHelper.getExtension('document.v2.final.pdf'), 'pdf');
      });

      test('should handle full file paths', () {
        expect(
          MediaTypeHelper.getExtension('/path/to/photo.jpg'),
          'jpg',
        );
        expect(
          MediaTypeHelper.getExtension('C:\\Users\\Documents\\file.pdf'),
          'pdf',
        );
      });

      test('should return empty string for files without extension', () {
        expect(MediaTypeHelper.getExtension('noextension'), '');
        expect(MediaTypeHelper.getExtension('Makefile'), '');
      });
    });

    group('isImage', () {
      test('should return true for image extensions', () {
        expect(MediaTypeHelper.isImage('photo.jpg'), true);
        expect(MediaTypeHelper.isImage('photo.jpeg'), true);
        expect(MediaTypeHelper.isImage('photo.png'), true);
        expect(MediaTypeHelper.isImage('photo.gif'), true);
        expect(MediaTypeHelper.isImage('photo.webp'), true);
        expect(MediaTypeHelper.isImage('photo.bmp'), true);
      });

      test('should return false for non-image extensions', () {
        expect(MediaTypeHelper.isImage('video.mp4'), false);
        expect(MediaTypeHelper.isImage('document.pdf'), false);
        expect(MediaTypeHelper.isImage('audio.mp3'), false);
      });

      test('should be case insensitive', () {
        expect(MediaTypeHelper.isImage('photo.JPG'), true);
        expect(MediaTypeHelper.isImage('photo.PNG'), true);
      });
    });

    group('isVideo', () {
      test('should return true for video extensions', () {
        expect(MediaTypeHelper.isVideo('video.mp4'), true);
        expect(MediaTypeHelper.isVideo('video.mov'), true);
        expect(MediaTypeHelper.isVideo('video.avi'), true);
        expect(MediaTypeHelper.isVideo('video.mkv'), true);
        expect(MediaTypeHelper.isVideo('video.webm'), true);
        expect(MediaTypeHelper.isVideo('video.flv'), true);
        expect(MediaTypeHelper.isVideo('video.3gp'), true);
        expect(MediaTypeHelper.isVideo('video.wmv'), true);
      });

      test('should return false for non-video extensions', () {
        expect(MediaTypeHelper.isVideo('photo.jpg'), false);
        expect(MediaTypeHelper.isVideo('document.pdf'), false);
        expect(MediaTypeHelper.isVideo('audio.mp3'), false);
      });
    });

    group('isAudio', () {
      test('should return true for audio extensions', () {
        expect(MediaTypeHelper.isAudio('audio.mp3'), true);
        expect(MediaTypeHelper.isAudio('audio.wav'), true);
        expect(MediaTypeHelper.isAudio('audio.aac'), true);
        expect(MediaTypeHelper.isAudio('audio.flac'), true);
        expect(MediaTypeHelper.isAudio('audio.ogg'), true);
        expect(MediaTypeHelper.isAudio('audio.m4a'), true);
        expect(MediaTypeHelper.isAudio('audio.wma'), true);
        expect(MediaTypeHelper.isAudio('audio.aiff'), true);
      });

      test('should return false for non-audio extensions', () {
        expect(MediaTypeHelper.isAudio('photo.jpg'), false);
        expect(MediaTypeHelper.isAudio('video.mp4'), false);
        expect(MediaTypeHelper.isAudio('document.pdf'), false);
      });
    });

    group('isDocument', () {
      test('should return true for document extensions', () {
        expect(MediaTypeHelper.isDocument('doc.pdf'), true);
        expect(MediaTypeHelper.isDocument('doc.doc'), true);
        expect(MediaTypeHelper.isDocument('doc.docx'), true);
        expect(MediaTypeHelper.isDocument('doc.xls'), true);
        expect(MediaTypeHelper.isDocument('doc.xlsx'), true);
        expect(MediaTypeHelper.isDocument('doc.ppt'), true);
        expect(MediaTypeHelper.isDocument('doc.pptx'), true);
        expect(MediaTypeHelper.isDocument('doc.txt'), true);
        expect(MediaTypeHelper.isDocument('doc.zip'), true);
        expect(MediaTypeHelper.isDocument('doc.csv'), true);
        expect(MediaTypeHelper.isDocument('doc.json'), true);
      });

      test('should return false for non-document extensions', () {
        expect(MediaTypeHelper.isDocument('photo.jpg'), false);
        expect(MediaTypeHelper.isDocument('video.mp4'), false);
        expect(MediaTypeHelper.isDocument('audio.mp3'), false);
      });
    });

    group('getMediaCategory', () {
      test('should return correct category for each type', () {
        expect(MediaTypeHelper.getMediaCategory('photo.jpg'), 'image');
        expect(MediaTypeHelper.getMediaCategory('video.mp4'), 'video');
        expect(MediaTypeHelper.getMediaCategory('audio.mp3'), 'audio');
        expect(MediaTypeHelper.getMediaCategory('doc.pdf'), 'document');
      });

      test('should return unknown for unsupported types', () {
        expect(MediaTypeHelper.getMediaCategory('file.xyz'), 'unknown');
        expect(MediaTypeHelper.getMediaCategory('file.abc'), 'unknown');
        expect(MediaTypeHelper.getMediaCategory('noextension'), 'unknown');
      });
    });

    group('isSupportedMedia', () {
      test('should return true for all supported types', () {
        expect(MediaTypeHelper.isSupportedMedia('photo.jpg'), true);
        expect(MediaTypeHelper.isSupportedMedia('video.mp4'), true);
        expect(MediaTypeHelper.isSupportedMedia('audio.mp3'), true);
        expect(MediaTypeHelper.isSupportedMedia('doc.pdf'), true);
      });

      test('should return false for unsupported types', () {
        expect(MediaTypeHelper.isSupportedMedia('file.xyz'), false);
        expect(MediaTypeHelper.isSupportedMedia('file.abc'), false);
        expect(MediaTypeHelper.isSupportedMedia('noextension'), false);
      });
    });

    group('getMediaTypeName', () {
      test('should return user-friendly names', () {
        expect(MediaTypeHelper.getMediaTypeName('photo.jpg'), 'Image');
        expect(MediaTypeHelper.getMediaTypeName('video.mp4'), 'Video');
        expect(MediaTypeHelper.getMediaTypeName('audio.mp3'), 'Audio');
        expect(MediaTypeHelper.getMediaTypeName('doc.pdf'), 'Document');
      });

      test('should return File for unknown types', () {
        expect(MediaTypeHelper.getMediaTypeName('file.xyz'), 'File');
        expect(MediaTypeHelper.getMediaTypeName('noextension'), 'File');
      });
    });

    group('edge cases', () {
      test('should handle empty string', () {
        expect(MediaTypeHelper.getExtension(''), '');
        expect(MediaTypeHelper.isImage(''), false);
        expect(MediaTypeHelper.isVideo(''), false);
        expect(MediaTypeHelper.isAudio(''), false);
        expect(MediaTypeHelper.isDocument(''), false);
        expect(MediaTypeHelper.getMediaCategory(''), 'unknown');
        expect(MediaTypeHelper.isSupportedMedia(''), false);
        expect(MediaTypeHelper.getMediaTypeName(''), 'File');
      });

      test('should handle files starting with dot', () {
        expect(MediaTypeHelper.getExtension('.gitignore'), 'gitignore');
        expect(MediaTypeHelper.getExtension('.hidden.jpg'), 'jpg');
      });

      test('should handle URLs with query parameters', () {
        // Note: This tests current behavior, URLs should be cleaned before passing
        expect(
          MediaTypeHelper.getExtension('photo.jpg?token=abc'),
          'jpg?token=abc',
        );
      });
    });
  });
}
