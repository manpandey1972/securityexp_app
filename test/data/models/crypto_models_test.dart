import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/data/models/crypto/crypto_models.dart';

void main() {
  // ===========================================================================
  // RoomKeyInfo
  // ===========================================================================

  group('RoomKeyInfo', () {
    test('should create with required fields', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final now = DateTime.utc(2026, 1, 15, 12, 0, 0);

      final info = RoomKeyInfo(
        roomId: 'alice_bob',
        key: key,
        retrievedAt: now,
      );

      expect(info.roomId, equals('alice_bob'));
      expect(info.key, equals(key));
      expect(info.key.length, equals(32));
      expect(info.retrievedAt, equals(now));
    });

    test('dispose should zero out key material', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final info = RoomKeyInfo(
        roomId: 'alice_bob',
        key: key,
        retrievedAt: DateTime.now(),
      );

      // Verify key has non-zero bytes
      expect(info.key.any((b) => b != 0), isTrue);

      info.dispose();

      // All bytes should be zero after dispose
      expect(info.key.every((b) => b == 0), isTrue);
    });

    test('toString should not expose key material', () {
      final info = RoomKeyInfo(
        roomId: 'alice_bob',
        key: Uint8List.fromList(List.generate(32, (i) => i)),
        retrievedAt: DateTime.utc(2026, 2, 1),
      );

      final str = info.toString();

      expect(str, contains('alice_bob'));
      expect(str, contains('retrievedAt'));
    });
  });

  // ===========================================================================
  // EncryptedMessage
  // ===========================================================================

  group('EncryptedMessage', () {
    test('should create with required fields', () {
      final ts = Timestamp.fromDate(DateTime(2026, 1, 15));

      final msg = EncryptedMessage(
        id: 'msg-123',
        senderId: 'user-456',
        type: 'text',
        ciphertext: base64Encode(Uint8List(64)),
        iv: base64Encode(Uint8List(12)),
        timestamp: ts,
      );

      expect(msg.id, equals('msg-123'));
      expect(msg.senderId, equals('user-456'));
      expect(msg.type, equals('text'));
      expect(msg.ciphertext.isNotEmpty, isTrue);
      expect(msg.iv.isNotEmpty, isTrue);
      expect(msg.encryptionVersion, equals(2));
    });

    test('should default encryptionVersion to 2', () {
      final msg = EncryptedMessage(
        id: 'msg-1',
        senderId: 'user-1',
        type: 'text',
        ciphertext: 'abc',
        iv: 'def',
        timestamp: Timestamp.now(),
      );

      expect(msg.encryptionVersion, equals(2));
    });

    test('should serialize to JSON correctly', () {
      final msg = EncryptedMessage(
        id: 'msg-456',
        senderId: 'user-789',
        type: 'image',
        ciphertext: base64Encode(Uint8List(128)),
        iv: base64Encode(Uint8List(12)),
        timestamp: Timestamp.fromDate(DateTime(2026, 2, 1)),
      );

      final json = msg.toJson();

      expect(json['sender_id'], equals('user-789'));
      expect(json['type'], equals('image'));
      expect(json['ciphertext'], isNotEmpty);
      expect(json['iv'], isNotEmpty);
      expect(json['encryption_version'], equals(2));
      // toJson should not include 'id' (Firestore doc ID is separate)
      expect(json.containsKey('id'), isFalse);
    });

    test('should deserialize from JSON correctly', () {
      final ts = Timestamp.fromDate(DateTime(2026, 1, 15));
      final json = {
        'id': 'msg-999',
        'sender_id': 'user-111',
        'type': 'audio',
        'ciphertext': base64Encode(Uint8List(48)),
        'iv': base64Encode(Uint8List(12)),
        'timestamp': ts,
        'encryption_version': 2,
      };

      final msg = EncryptedMessage.fromJson(json);

      expect(msg.id, equals('msg-999'));
      expect(msg.senderId, equals('user-111'));
      expect(msg.type, equals('audio'));
      expect(msg.encryptionVersion, equals(2));
    });

    test('should handle missing optional fields in fromJson', () {
      final json = <String, dynamic>{
        'ciphertext': 'abc',
        'iv': 'def',
      };

      final msg = EncryptedMessage.fromJson(json);

      expect(msg.id, equals(''));
      expect(msg.senderId, equals(''));
      expect(msg.type, equals('text'));
      expect(msg.encryptionVersion, equals(2));
    });

    test('should support Equatable equality', () {
      final ts = Timestamp.fromDate(DateTime(2026, 1, 15));
      final ct = base64Encode(Uint8List(64));
      final iv = base64Encode(Uint8List(12));

      final a = EncryptedMessage(
        id: 'msg-1',
        senderId: 'user-1',
        type: 'text',
        ciphertext: ct,
        iv: iv,
        timestamp: ts,
      );

      final b = EncryptedMessage(
        id: 'msg-1',
        senderId: 'user-1',
        type: 'text',
        ciphertext: ct,
        iv: iv,
        timestamp: ts,
      );

      expect(a, equals(b));
    });

    test('should not be equal when fields differ', () {
      final ts = Timestamp.fromDate(DateTime(2026, 1, 15));

      final a = EncryptedMessage(
        id: 'msg-1',
        senderId: 'user-1',
        type: 'text',
        ciphertext: 'cipher_a',
        iv: 'iv_a',
        timestamp: ts,
      );

      final b = EncryptedMessage(
        id: 'msg-1',
        senderId: 'user-1',
        type: 'text',
        ciphertext: 'cipher_b',
        iv: 'iv_b',
        timestamp: ts,
      );

      expect(a == b, isFalse);
    });
  });

  // ===========================================================================
  // DecryptedContent
  // ===========================================================================

  group('DecryptedContent', () {
    test('should serialize to bytes and back for text', () {
      final content = DecryptedContent(
        text: 'Hello, encrypted world!',
      );

      final bytes = content.toBytes();
      expect(bytes.isNotEmpty, true);

      final restored = DecryptedContent.fromBytes(bytes);
      expect(restored.text, 'Hello, encrypted world!');
    });

    test('should handle media fields', () {
      final content = DecryptedContent(
        text: 'Check this out',
        mediaUrl: 'gs://bucket/encrypted_file.bin',
        mediaType: 'image/jpeg',
        mediaSize: 1024000,
        fileName: 'photo.jpg',
      );

      final bytes = content.toBytes();
      final restored = DecryptedContent.fromBytes(bytes);

      expect(restored.text, 'Check this out');
      expect(restored.mediaUrl, 'gs://bucket/encrypted_file.bin');
      expect(restored.mediaType, 'image/jpeg');
      expect(restored.mediaSize, 1024000);
      expect(restored.fileName, 'photo.jpg');
    });

    test('should handle reply metadata', () {
      final content = DecryptedContent(
        text: 'I agree!',
        replyToMessageId: 'msg_original_123',
        metadata: {'reaction': 'thumbsup'},
      );

      final bytes = content.toBytes();
      final restored = DecryptedContent.fromBytes(bytes);

      expect(restored.replyToMessageId, 'msg_original_123');
      expect(restored.metadata?['reaction'], 'thumbsup');
    });
  });
}
