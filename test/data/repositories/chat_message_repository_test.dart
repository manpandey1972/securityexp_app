import 'package:flutter_test/flutter_test.dart';

import 'package:securityexperts_app/data/models/models.dart';

/// Unit tests for ChatMessageRepository and Message model
///
/// Tests cover model parsing, message types, and edge cases.
/// Integration tests with Firestore require FakeFirebaseFirestore setup.
void main() {
  group('Message Model', () {
    group('fromJson', () {
      test('should parse complete text message from JSON', () {
        final json = {
          'id': 'msg-123',
          'sender_id': 'user-456',
          'type': 'text',
          'text': 'Hello, world!',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15, 10, 30)),
        };

        final message = Message.fromJson(json);

        expect(message.id, equals('msg-123'));
        expect(message.senderId, equals('user-456'));
        expect(message.type, equals(MessageType.text));
        expect(message.text, equals('Hello, world!'));
        expect(message.mediaUrl, isNull);
        expect(message.replyToMessageId, isNull);
      });

      test('should parse image message with media URL', () {
        final json = {
          'id': 'msg-124',
          'sender_id': 'user-456',
          'type': 'image',
          'text': '',
          'media_url': 'https://storage.example.com/images/photo.jpg',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.image));
        expect(message.mediaUrl, equals('https://storage.example.com/images/photo.jpg'));
      });

      test('should parse video message', () {
        final json = {
          'id': 'msg-125',
          'sender_id': 'user-456',
          'type': 'video',
          'media_url': 'https://storage.example.com/videos/clip.mp4',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.video));
        expect(message.mediaUrl, contains('clip.mp4'));
      });

      test('should parse audio message', () {
        final json = {
          'id': 'msg-126',
          'sender_id': 'user-456',
          'type': 'audio',
          'media_url': 'https://storage.example.com/audio/voice.m4a',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.audio));
      });

      test('should parse system message', () {
        final json = {
          'id': 'msg-127',
          'sender_id': 'system',
          'type': 'system',
          'text': 'User joined the chat',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.system));
        expect(message.text, equals('User joined the chat'));
      });

      test('should parse document message', () {
        final json = {
          'id': 'msg-128',
          'sender_id': 'user-456',
          'type': 'doc',
          'text': 'report.pdf',
          'media_url': 'https://storage.example.com/docs/report.pdf',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.doc));
      });

      test('should parse call log message', () {
        final json = {
          'id': 'msg-129',
          'sender_id': 'user-456',
          'type': 'call_log',
          'text': 'Missed call',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
          'metadata': {
            'callType': 'video',
            'duration': 0,
            'status': 'missed',
          },
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.callLog));
        expect(message.metadata, isNotNull);
        expect(message.metadata!['callType'], equals('video'));
      });

      test('should parse message with reply', () {
        final json = {
          'id': 'msg-130',
          'sender_id': 'user-456',
          'type': 'text',
          'text': 'This is a reply',
          'replyToMessageId': 'msg-100',
          'replyToMessage': {
            'id': 'msg-100',
            'sender_id': 'user-789',
            'type': 'text',
            'text': 'Original message',
            'timestamp': Timestamp.fromDate(DateTime(2026, 1, 14)),
          },
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.replyToMessageId, equals('msg-100'));
        expect(message.replyToMessage, isNotNull);
        expect(message.replyToMessage!.text, equals('Original message'));
      });

      test('should handle missing optional fields', () {
        final json = {
          'sender_id': 'user-456',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.id, equals(''));
        expect(message.text, equals(''));
        expect(message.type, equals(MessageType.text)); // Default
        expect(message.mediaUrl, isNull);
      });

      test('should default to text type for unknown type', () {
        final json = {
          'id': 'msg-131',
          'sender_id': 'user-456',
          'type': 'unknown_type',
          'text': 'Test',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
        };

        final message = Message.fromJson(json);

        expect(message.type, equals(MessageType.text));
      });

      test('should use Timestamp.now() when timestamp is null', () {
        final json = {
          'id': 'msg-132',
          'sender_id': 'user-456',
          'text': 'Test',
        };

        final beforeParse = Timestamp.now();
        final message = Message.fromJson(json);
        final afterParse = Timestamp.now();

        expect(message.timestamp.millisecondsSinceEpoch,
            greaterThanOrEqualTo(beforeParse.millisecondsSinceEpoch));
        expect(message.timestamp.millisecondsSinceEpoch,
            lessThanOrEqualTo(afterParse.millisecondsSinceEpoch + 1000));
      });
    });

    group('toJson', () {
      test('should convert message to JSON', () {
        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.text,
          text: 'Hello!',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        );

        final json = message.toJson();

        expect(json['id'], equals('msg-123'));
        expect(json['sender_id'], equals('user-456'));
        expect(json['type'], equals('text'));
        expect(json['text'], equals('Hello!'));
        expect(json['timestamp'], isA<Timestamp>());
      });

      test('should include media_url when present', () {
        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.image,
          mediaUrl: 'https://example.com/photo.jpg',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        );

        final json = message.toJson();

        expect(json['media_url'], equals('https://example.com/photo.jpg'));
      });

      test('should include reply info when present', () {
        final originalMessage = Message(
          id: 'msg-100',
          senderId: 'user-789',
          type: MessageType.text,
          text: 'Original',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 14)),
        );

        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.text,
          text: 'Reply',
          replyToMessageId: 'msg-100',
          replyToMessage: originalMessage,
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        );

        final json = message.toJson();

        expect(json['replyToMessageId'], equals('msg-100'));
        expect(json['replyToMessage'], isA<Map>());
      });

      test('should include metadata when present', () {
        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.callLog,
          text: 'Missed call',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
          metadata: {'duration': 120, 'callType': 'audio'},
        );

        final json = message.toJson();

        expect(json['metadata'], isA<Map>());
        expect(json['metadata']['duration'], equals(120));
      });

      test('should omit null optional fields', () {
        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.text,
          text: 'Simple text',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        );

        final json = message.toJson();

        expect(json.containsKey('media_url'), equals(false));
        expect(json.containsKey('replyToMessageId'), equals(false));
        expect(json.containsKey('replyToMessage'), equals(false));
        expect(json.containsKey('metadata'), equals(false));
      });
    });

    group('copyWith', () {
      test('should create copy with updated text', () {
        final original = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.text,
          text: 'Original text',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        );

        final updated = original.copyWith(text: 'Updated text');

        expect(updated.id, equals('msg-123'));
        expect(updated.text, equals('Updated text'));
        expect(original.text, equals('Original text')); // Original unchanged
      });

      test('should preserve all fields when no updates', () {
        final original = Message(
          id: 'msg-123',
          senderId: 'user-456',
          type: MessageType.image,
          text: 'Caption',
          mediaUrl: 'https://example.com/photo.jpg',
          replyToMessageId: 'msg-100',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
          metadata: {'width': 1920, 'height': 1080},
        );

        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.senderId, equals(original.senderId));
        expect(copy.type, equals(original.type));
        expect(copy.text, equals(original.text));
        expect(copy.mediaUrl, equals(original.mediaUrl));
        expect(copy.replyToMessageId, equals(original.replyToMessageId));
        expect(copy.metadata, equals(original.metadata));
      });
    });

    group('Convenience getters', () {
      test('dateTime should return DateTime from timestamp', () {
        final timestamp = Timestamp.fromDate(DateTime(2026, 1, 15, 10, 30));
        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          timestamp: timestamp,
        );

        expect(message.dateTime.year, equals(2026));
        expect(message.dateTime.month, equals(1));
        expect(message.dateTime.day, equals(15));
        expect(message.dateTime.hour, equals(10));
        expect(message.dateTime.minute, equals(30));
      });

      test('millisecondsSinceEpoch should return correct value', () {
        final dt = DateTime(2026, 1, 15, 10, 30);
        final timestamp = Timestamp.fromDate(dt);
        final message = Message(
          id: 'msg-123',
          senderId: 'user-456',
          timestamp: timestamp,
        );

        expect(message.millisecondsSinceEpoch, equals(dt.millisecondsSinceEpoch));
      });
    });
  });

  group('MessageType Enum', () {
    test('should convert to JSON correctly', () {
      expect(MessageType.text.toJson(), equals('text'));
      expect(MessageType.image.toJson(), equals('image'));
      expect(MessageType.video.toJson(), equals('video'));
      expect(MessageType.audio.toJson(), equals('audio'));
      expect(MessageType.system.toJson(), equals('system'));
      expect(MessageType.doc.toJson(), equals('doc'));
      expect(MessageType.callLog.toJson(), equals('call_log'));
    });

    test('should parse from JSON correctly', () {
      expect(MessageTypeExtension.fromJson('text'), equals(MessageType.text));
      expect(MessageTypeExtension.fromJson('image'), equals(MessageType.image));
      expect(MessageTypeExtension.fromJson('video'), equals(MessageType.video));
      expect(MessageTypeExtension.fromJson('audio'), equals(MessageType.audio));
      expect(MessageTypeExtension.fromJson('system'), equals(MessageType.system));
      expect(MessageTypeExtension.fromJson('doc'), equals(MessageType.doc));
      expect(MessageTypeExtension.fromJson('call_log'), equals(MessageType.callLog));
    });

    test('should handle case-insensitive parsing', () {
      expect(MessageTypeExtension.fromJson('TEXT'), equals(MessageType.text));
      expect(MessageTypeExtension.fromJson('Image'), equals(MessageType.image));
      expect(MessageTypeExtension.fromJson('VIDEO'), equals(MessageType.video));
    });

    test('should default to text for unknown types', () {
      expect(MessageTypeExtension.fromJson('unknown'), equals(MessageType.text));
      expect(MessageTypeExtension.fromJson(''), equals(MessageType.text));
    });
  });

  group('Message JSON Roundtrip', () {
    test('should survive JSON roundtrip for text message', () {
      final original = Message(
        id: 'msg-123',
        senderId: 'user-456',
        type: MessageType.text,
        text: 'Test message with emoji 🎉',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15, 10, 30)),
      );

      final json = original.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.senderId, equals(original.senderId));
      expect(restored.type, equals(original.type));
      expect(restored.text, equals(original.text));
      expect(restored.timestamp.toDate().year, equals(original.timestamp.toDate().year));
    });

    test('should survive JSON roundtrip for media message', () {
      final original = Message(
        id: 'msg-124',
        senderId: 'user-456',
        type: MessageType.image,
        text: 'Image caption',
        mediaUrl: 'https://storage.example.com/images/photo.jpg',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        metadata: {'width': 1920, 'height': 1080, 'mimeType': 'image/jpeg'},
      );

      final json = original.toJson();
      final restored = Message.fromJson(json);

      expect(restored.type, equals(MessageType.image));
      expect(restored.mediaUrl, equals(original.mediaUrl));
      expect(restored.metadata!['width'], equals(1920));
    });

    test('should survive JSON roundtrip for reply message', () {
      final replyTo = Message(
        id: 'msg-100',
        senderId: 'user-789',
        type: MessageType.text,
        text: 'Original message',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 14)),
      );

      final original = Message(
        id: 'msg-125',
        senderId: 'user-456',
        type: MessageType.text,
        text: 'This is a reply',
        replyToMessageId: 'msg-100',
        replyToMessage: replyTo,
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
      );

      final json = original.toJson();
      final restored = Message.fromJson(json);

      expect(restored.replyToMessageId, equals('msg-100'));
      expect(restored.replyToMessage, isNotNull);
      expect(restored.replyToMessage!.text, equals('Original message'));
    });
  });

  group('Message Sorting', () {
    test('should sort messages by timestamp', () {
      final messages = [
        Message(
          id: 'msg-3',
          senderId: 'user-456',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15, 12, 0)),
        ),
        Message(
          id: 'msg-1',
          senderId: 'user-456',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15, 10, 0)),
        ),
        Message(
          id: 'msg-2',
          senderId: 'user-456',
          timestamp: Timestamp.fromDate(DateTime(2026, 1, 15, 11, 0)),
        ),
      ];

      messages.sort((a, b) =>
          a.timestamp.millisecondsSinceEpoch.compareTo(b.timestamp.millisecondsSinceEpoch));

      expect(messages[0].id, equals('msg-1'));
      expect(messages[1].id, equals('msg-2'));
      expect(messages[2].id, equals('msg-3'));
    });
  });
}
