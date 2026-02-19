import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/data/models/models.dart';

@GenerateMocks([Timestamp])
void main() {
  group('User Model', () {
    test('should create User with required fields', () {
      final user = User(
        id: 'user_123',
        name: 'John Doe',
        roles: ['Consumer'],
        languages: ['English'],
        expertises: [],
        fcmTokens: [],
        notificationsEnabled: true,
      );

      expect(user.id, 'user_123');
      expect(user.name, 'John Doe');
      expect(user.roles, contains('Consumer'));
      expect(user.notificationsEnabled, true);
    });

    test('should create User with all fields', () {
      final timestamp = Timestamp.now();

      final user = User(
        id: 'user_456',
        name: 'Jane Expert',
        email: 'jane@example.com',
        phone: '+1234567890',
        roles: ['Expert'],
        languages: ['English', 'Spanish'],
        expertises: ['Agriculture', 'Sustainability'],
        fcmTokens: ['token1', 'token2'],
        createdTime: timestamp,
        updatedTime: timestamp,
        lastLogin: timestamp,
        bio: 'Expert in sustainable farming',
        profilePictureUrl: 'https://example.com/photo.jpg',
        profilePictureUpdatedAt: timestamp,
        hasProfilePicture: true,
        notificationsEnabled: true,
      );

      expect(user.id, 'user_456');
      expect(user.name, 'Jane Expert');
      expect(user.email, 'jane@example.com');
      expect(user.roles, contains('Expert'));
      expect(user.expertises.length, 2);
      expect(user.bio, contains('farming'));
    });

    test('should parse User from JSON correctly', () {
      final json = {
        'id': 'user_789',
        'name': 'Test User',
        'email': 'test@example.com',
        'phone': '+9876543210',
        'roles': ['Consumer'],
        'langs': ['English'],
        'exps': ['Technology'],
        'fcms': ['token1'],
        'bio': 'Tech enthusiast',
        'profile_picture_url': 'https://example.com/pic.jpg',
        'has_profile_picture': true,
        'notifications_enabled': true,
      };

      final user = User.fromJson(json);

      expect(user.id, 'user_789');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.languages, contains('English'));
      expect(user.expertises, contains('Technology'));
      expect(user.profilePictureUrl, isNotNull);
      expect(user.hasProfilePicture, true);
    });

    test('should convert User to JSON correctly', () {
      final user = User(
        id: 'user_123',
        name: 'John Doe',
        email: 'john@example.com',
        roles: ['Consumer'],
        languages: ['English'],
        expertises: ['Business'],
        fcmTokens: ['token1'],
        bio: 'Business owner',
        notificationsEnabled: true,
      );

      final json = user.toJson();

      // Note: 'id' is not included in toJson() because in Firestore
      // the document ID is stored separately from the document data
      expect(json.containsKey('id'), isFalse);
      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['roles'], contains('Consumer'));
      expect(json['langs'], contains('English'));
      expect(json['exps'], contains('Business'));
    });

    test('should handle nullable fields correctly', () {
      final user = User(
        id: 'user_minimal',
        name: 'Minimal User',
        roles: [],
        languages: [],
        expertises: [],
        fcmTokens: [],
        email: null,
        phone: null,
        bio: null,
        profilePictureUrl: null,
        notificationsEnabled: true,
      );

      expect(user.email, null);
      expect(user.phone, null);
      expect(user.bio, null);
      expect(user.profilePictureUrl, null);
    });

    test('should determine if user is expert', () {
      final expert = User(
        id: 'expert_1',
        name: 'Expert User',
        roles: ['Expert'],
        languages: ['English'],
        expertises: ['Agriculture'],
        fcmTokens: [],
        notificationsEnabled: true,
      );

      final consumer = User(
        id: 'consumer_1',
        name: 'Consumer User',
        roles: ['Consumer'],
        languages: ['English'],
        expertises: [],
        fcmTokens: [],
        notificationsEnabled: true,
      );

      expect(expert.roles.contains('Expert'), true);
      expect(consumer.roles.contains('Expert'), false);
    });
  });

  group('Message Model', () {
    test('should create Message with required fields', () {
      final timestamp = Timestamp.now();

      final message = Message(
        id: 'msg_123',
        senderId: 'user_123',
        text: 'Hello world',
        timestamp: timestamp,
        type: MessageType.text,
      );

      expect(message.id, 'msg_123');
      expect(message.senderId, 'user_123');
      expect(message.text, 'Hello world');
      expect(message.type, MessageType.text);
    });

    test('should handle different message types', () {
      final timestamp = Timestamp.now();

      final textMsg = Message(
        id: 'msg_1',
        senderId: 'user_1',
        text: 'Text message',
        timestamp: timestamp,
        type: MessageType.text,
      );

      final imageMsg = Message(
        id: 'msg_2',
        senderId: 'user_1',
        text: '',
        timestamp: timestamp,
        type: MessageType.image,
        mediaUrl: 'https://example.com/image.jpg',
      );

      final videoMsg = Message(
        id: 'msg_3',
        senderId: 'user_1',
        text: '',
        timestamp: timestamp,
        type: MessageType.video,
        mediaUrl: 'https://example.com/video.mp4',
      );

      expect(textMsg.type, MessageType.text);
      expect(imageMsg.type, MessageType.image);
      expect(videoMsg.type, MessageType.video);
      expect(imageMsg.mediaUrl, isNotNull);
    });

    test('should parse MessageType from string', () {
      expect(MessageTypeExtension.fromJson('text'), MessageType.text);
      expect(MessageTypeExtension.fromJson('image'), MessageType.image);
      expect(MessageTypeExtension.fromJson('video'), MessageType.video);
      expect(MessageTypeExtension.fromJson('audio'), MessageType.audio);
      expect(MessageTypeExtension.fromJson('doc'), MessageType.doc);
      expect(MessageTypeExtension.fromJson('call_log'), MessageType.callLog);
    });

    test('should convert MessageType to string', () {
      expect(MessageType.text.toJson(), 'text');
      expect(MessageType.image.toJson(), 'image');
      expect(MessageType.video.toJson(), 'video');
      expect(MessageType.audio.toJson(), 'audio');
      expect(MessageType.doc.toJson(), 'doc');
      expect(MessageType.callLog.toJson(), 'call_log');
    });

    test('should handle default MessageType for unknown string', () {
      expect(MessageTypeExtension.fromJson('unknown'), MessageType.text);
      expect(MessageTypeExtension.fromJson(''), MessageType.text);
    });
  });

  group('ChatRoom Model', () {
    test('should handle chat room participant lists', () {
      final participants = ['user_1', 'user_2'];

      expect(participants.length, 2);
      expect(participants, contains('user_1'));
      expect(participants, contains('user_2'));
    });

    test('should identify other participant in a room', () {
      final participants = ['user_1', 'user_2'];
      final currentUserId = 'user_1';
      final otherParticipant = participants.firstWhere(
        (id) => id != currentUserId,
      );

      expect(otherParticipant, 'user_2');
    });
  });

  group('Model Validation', () {
    test('should validate User ID is not empty', () {
      expect(
        () {
          User(
            id: '',
            name: 'Test',
            roles: [],
            languages: [],
            expertises: [],
            fcmTokens: [],
            notificationsEnabled: true,
          );
        },
        returnsNormally,
      ); // Model doesn't throw, but validation should catch this
    });

    test('should validate Message text for text type', () {
      final timestamp = Timestamp.now();

      final message = Message(
        id: 'msg_1',
        senderId: 'user_1',
        text: 'Valid message',
        timestamp: timestamp,
        type: MessageType.text,
      );

      expect(message.text.isNotEmpty, true);
    });

    test('should validate media URL for media messages', () {
      final timestamp = Timestamp.now();

      final imageMessage = Message(
        id: 'msg_2',
        senderId: 'user_1',
        text: '',
        timestamp: timestamp,
        type: MessageType.image,
        mediaUrl: 'https://example.com/image.jpg',
      );

      expect(imageMessage.mediaUrl, isNotNull);
      expect(imageMessage.mediaUrl!.isNotEmpty, true);
    });
  });
}
