import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/data/models/models.dart';

/// Unit tests for E2EE integration in the Message model.
///
/// Tests cover new E2EE fields (isEncrypted, decryptionFailed),
/// JSON serialization, copyWith behavior, and equality.
void main() {
  // ===========================================================================
  // Message E2EE fields
  // ===========================================================================

  group('Message E2EE Fields', () {
    test('should default isEncrypted to false', () {
      final message = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
      );

      expect(message.isEncrypted, isFalse);
      expect(message.decryptionFailed, isFalse);
    });

    test('should create encrypted message', () {
      final message = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Decrypted content',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        isEncrypted: true,
      );

      expect(message.isEncrypted, isTrue);
      expect(message.decryptionFailed, isFalse);
    });

    test('should create message with decryption failure', () {
      final message = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: '\u{1F512} Unable to decrypt this message',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        isEncrypted: true,
        decryptionFailed: true,
      );

      expect(message.isEncrypted, isTrue);
      expect(message.decryptionFailed, isTrue);
      expect(message.text, contains('Unable to decrypt'));
    });

    test('copyWith should update isEncrypted', () {
      final original = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
      );

      final encrypted = original.copyWith(isEncrypted: true);

      expect(original.isEncrypted, isFalse);
      expect(encrypted.isEncrypted, isTrue);
      expect(encrypted.text, equals('Hello'));
      expect(encrypted.id, equals('msg-1'));
    });

    test('copyWith should update decryptionFailed', () {
      final original = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        isEncrypted: true,
      );

      final failed = original.copyWith(decryptionFailed: true);

      expect(failed.isEncrypted, isTrue);
      expect(failed.decryptionFailed, isTrue);
    });

    test('copyWith should preserve E2EE fields when not specified', () {
      final original = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        isEncrypted: true,
        decryptionFailed: true,
      );

      final copy = original.copyWith(text: 'Updated');

      expect(copy.isEncrypted, isTrue);
      expect(copy.decryptionFailed, isTrue);
      expect(copy.text, equals('Updated'));
    });

    test('equality should include E2EE fields', () {
      final timestamp = Timestamp.fromDate(DateTime(2026, 1, 15));

      final msg1 = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: timestamp,
        isEncrypted: true,
      );

      final msg2 = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: timestamp,
        isEncrypted: false,
      );

      // Same content but different isEncrypted => not equal
      expect(msg1 == msg2, isFalse);
    });

    test('equality should match when all fields are equal', () {
      final timestamp = Timestamp.fromDate(DateTime(2026, 1, 15));

      final msg1 = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: timestamp,
        isEncrypted: true,
        decryptionFailed: false,
      );

      final msg2 = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: timestamp,
        isEncrypted: true,
        decryptionFailed: false,
      );

      expect(msg1 == msg2, isTrue);
    });
  });

  // ===========================================================================
  // Message fromJson with E2EE fields
  // ===========================================================================

  group('Message fromJson E2EE', () {
    test('should parse standard message without E2EE fields', () {
      final json = {
        'id': 'msg-1',
        'sender_id': 'user-1',
        'type': 'text',
        'text': 'Hello',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 15)),
      };

      final message = Message.fromJson(json);

      expect(message.isEncrypted, isFalse);
      expect(message.decryptionFailed, isFalse);
    });
  });

  // ===========================================================================
  // Message toJson with E2EE fields
  // ===========================================================================

  group('Message toJson E2EE', () {
    test('should not include E2EE fields in toJson (transient fields)', () {
      final message = Message(
        id: 'msg-1',
        senderId: 'user-1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.fromDate(DateTime(2026, 1, 15)),
        isEncrypted: true,
        decryptionFailed: true,
      );

      final json = message.toJson();

      // isEncrypted and decryptionFailed are client-side transient fields
      // They should not be serialized to Firestore
      expect(json.containsKey('isEncrypted'), isFalse);
      expect(json.containsKey('decryptionFailed'), isFalse);
    });
  });
}
