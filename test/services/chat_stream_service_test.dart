import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:securityexperts_app/features/chat/services/chat_stream_service.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import 'chat_stream_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ChatMessageRepository>(),
  MockSpec<AppLogger>(),
])
void main() {
  late ChatStreamService service;
  late MockChatMessageRepository mockMessageRepository;
  late MockAppLogger mockLogger;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockMessageRepository = MockChatMessageRepository();
    mockLogger = MockAppLogger();

    // Register mock logger
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockLogger);

    // Create mock Firebase Auth with signed-in user
    final mockUser = MockUser(uid: 'user123', email: 'test@test.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

    service = ChatStreamService(
      roomId: 'room123',
      messageRepository: mockMessageRepository,
      auth: mockAuth,
    );
  });

  tearDown(() {
    service.dispose();
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('Initialization', () {
    test('should create service with required roomId', () {
      // Assert
      expect(service.roomId, equals('room123'));
      expect(service.messages, isEmpty);
    });

    test('should create service with default dependencies', () {
      // Act
      final service = ChatStreamService(roomId: 'room456');

      // Assert
      expect(service, isNotNull);
      expect(service.roomId, equals('room456'));
    }, skip: 'Requires Firebase initialization which is not available in unit tests');
  });

  group('Message Stream', () {
    test('startListening should subscribe to messages stream', () async {
      // Arrange
      final messages = [
        Message(
          id: 'msg1',
          senderId: 'user123',
          type: MessageType.text,
          text: 'Hello',
          timestamp: Timestamp.now(),
        ),
      ];
      final streamController = StreamController<List<Message>>();
      when(mockMessageRepository.getMessagesStream(
        'room123',
        limit: anyNamed('limit'),
      )).thenAnswer((_) => streamController.stream);

      bool callbackCalled = false;
      service.onMessagesUpdated = (msgs) {
        callbackCalled = true;
      };

      // Act
      service.startListening();
      streamController.add(messages);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(callbackCalled, isTrue);
      expect(service.messages, equals(messages));
      verify(mockMessageRepository.getMessagesStream(
        'room123',
        limit: anyNamed('limit'),
      )).called(1);

      // Cleanup
      await streamController.close();
    });

    test('should update messages list when stream emits', () async {
      // Arrange
      final message1 = Message(
        id: 'msg1',
        senderId: 'user123',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.now(),
      );
      final message2 = Message(
        id: 'msg2',
        senderId: 'user456',
        type: MessageType.text,
        text: 'Hi there',
        timestamp: Timestamp.now(),
      );

      final streamController = StreamController<List<Message>>();
      when(mockMessageRepository.getMessagesStream(
        'room123',
        limit: anyNamed('limit'),
      )).thenAnswer((_) => streamController.stream);

      final receivedMessages = <List<Message>>[];
      service.onMessagesUpdated = (msgs) {
        receivedMessages.add(List.from(msgs));
      };

      // Act
      service.startListening();
      streamController.add([message1]);
      await Future.delayed(const Duration(milliseconds: 50));
      streamController.add([message1, message2]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(receivedMessages.length, equals(2));
      expect(receivedMessages[0].length, equals(1));
      expect(receivedMessages[1].length, equals(2));
      expect(service.messages.length, equals(2));

      // Cleanup
      await streamController.close();
    });

    test('should call onError callback when stream has error', () async {
      // Arrange
      final streamController = StreamController<List<Message>>();
      when(mockMessageRepository.getMessagesStream(
        'room123',
        limit: anyNamed('limit'),
      )).thenAnswer((_) => streamController.stream);

      String? errorMessage;
      service.onError = (error) {
        errorMessage = error;
      };

      // Act
      service.startListening();
      streamController.addError(Exception('Stream error'));
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(errorMessage, contains('Stream error'));

      // Cleanup
      await streamController.close();
    });

    test('should clear previous messages when new batch arrives', () async {
      // Arrange
      final message1 = Message(
        id: 'msg1',
        senderId: 'user123',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.now(),
      );
      final message2 = Message(
        id: 'msg2',
        senderId: 'user456',
        type: MessageType.text,
        text: 'Different message',
        timestamp: Timestamp.now(),
      );

      final streamController = StreamController<List<Message>>();
      when(mockMessageRepository.getMessagesStream(
        'room123',
        limit: anyNamed('limit'),
      )).thenAnswer((_) => streamController.stream);

      // Act
      service.startListening();
      streamController.add([message1]);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Replace with completely different message
      streamController.add([message2]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(service.messages.length, equals(1));
      expect(service.messages[0].id, equals('msg2'));

      // Cleanup
      await streamController.close();
    });
  });

  group('Disposal', () {
    test('dispose should cancel subscription and clear messages', () async {
      // Arrange
      final streamController = StreamController<List<Message>>();
      when(mockMessageRepository.getMessagesStream(
        'room123',
        limit: anyNamed('limit'),
      )).thenAnswer((_) => streamController.stream);

      service.startListening();
      streamController.add([
        Message(
          id: 'msg1',
          senderId: 'user123',
          type: MessageType.text,
          text: 'Hello',
          timestamp: Timestamp.now(),
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Act
      service.dispose();

      // Assert
      expect(service.messages, isEmpty);

      // Cleanup
      await streamController.close();
    });

    test('dispose should be safe to call multiple times', () {
      // Act & Assert
      expect(() {
        service.dispose();
        service.dispose();
      }, returnsNormally);
    });
  });

  group('Error Handling', () {
    test('should handle errors gracefully in startListening', () {
      // Arrange
      when(mockMessageRepository.getMessagesStream(
        any,
        limit: anyNamed('limit'),
      )).thenThrow(Exception('Connection error'));

      String? errorMessage;
      service.onError = (error) {
        errorMessage = error;
      };

      // Act
      service.startListening();

      // Assert
      expect(errorMessage, contains('Error starting message streams'));
    });
  });
}
