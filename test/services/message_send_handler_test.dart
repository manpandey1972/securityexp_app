import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:securityexperts_app/features/chat/services/message_send_handler.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_filter_service.dart';
import 'package:securityexperts_app/shared/services/profanity/profanity_models.dart';

import 'message_send_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ChatMessageRepository>(),
  MockSpec<ItemScrollController>(),
  MockSpec<ProfanityFilterService>(),
])

// Dummy logger implementation for tests
class _DummyLogger implements AppLogger {
  @override
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {}
  @override
  void error(String message, {String? tag, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {}
  @override
  void info(String message, {String? tag, Map<String, dynamic>? data}) {}
  @override
  void verbose(String message, {String? tag, Map<String, dynamic>? data}) {}
  @override
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
    // Register a dummy AppLogger for GetIt

    setUpAll(() {
      if (sl.isRegistered<AppLogger>()) {
        sl.unregister<AppLogger>();
      }
      sl.registerSingleton<AppLogger>(_DummyLogger());
      
      if (sl.isRegistered<ProfanityFilterService>()) {
        sl.unregister<ProfanityFilterService>();
      }
    });

  late MessageSendHandler handler;
  late MockChatMessageRepository mockMessageRepository;
  late MockItemScrollController mockScrollController;
  late MockFirebaseAuth mockAuth;
  late MockProfanityFilterService mockProfanityFilter;

  Message? replyToMessage;
  bool replyClearCalled = false;

  setUp(() {
    mockMessageRepository = MockChatMessageRepository();
    mockScrollController = MockItemScrollController();
    mockProfanityFilter = MockProfanityFilterService();

    // Register mock profanity filter
    if (sl.isRegistered<ProfanityFilterService>()) {
      sl.unregister<ProfanityFilterService>();
    }
    sl.registerSingleton<ProfanityFilterService>(mockProfanityFilter);
    
    // By default, mock returns clean result (no profanity)
    when(mockProfanityFilter.checkProfanitySync(any, context: anyNamed('context')))
        .thenReturn(ProfanityResult.clean());

    replyToMessage = null;
    replyClearCalled = false;

    replyToMessage = null;
    replyClearCalled = false;

    // Use firebase_auth_mocks to mock FirebaseAuth
    final mockUser = MockUser(uid: 'user123', email: 'test@test.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

    handler = MessageSendHandler(
      messageRepository: mockMessageRepository,
      roomId: 'room123',
      itemScrollController: mockScrollController,
      getReplyToMessage: () => replyToMessage,
      clearReply: () {
        replyClearCalled = true;
        replyToMessage = null;
      },
      firebaseAuth: mockAuth,
    );
  });



  group('Send Message', () {
    test('should not send empty message', () async {
      // Arrange
      bool successCalled = false;

      // Act
      await handler.sendMessage(
        text: '',
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isFalse);
      verifyNever(mockMessageRepository.sendMessage(any, any));
    });

    test('should not send whitespace-only message', () async {
      // Arrange
      bool successCalled = false;

      // Act
      await handler.sendMessage(
        text: '   ',
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isFalse);
      verifyNever(mockMessageRepository.sendMessage(any, any));
    });

    test('should send text message successfully', () async {
      // Arrange
      const messageText = 'Hello, World!';
      bool successCalled = false;
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: messageText,
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: messageText,
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isTrue);
      verify(mockMessageRepository.sendMessage(
        'room123',
        argThat(isA<Message>()
            .having((m) => m.text, 'text', messageText)
            .having((m) => m.type, 'type', MessageType.text)),
      )).called(1);
    });

    test('should include reply reference when replying', () async {
      // Arrange
      const messageText = 'Reply text';
      replyToMessage = Message(
        id: 'original_msg',
        senderId: 'user456',
        type: MessageType.text,
        text: 'Original message',
        timestamp: Timestamp.now(),
      );
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: messageText,
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: messageText,
        onSuccess: () {},
      );

      // Assert
      verify(mockMessageRepository.sendMessage(
        'room123',
        argThat(isA<Message>()
        .having((m) => m.replyToMessageId, 'replyToMessageId', 'original_msg')
        .having((m) => m.replyToMessage, 'replyToMessage', isNotNull)),
      )).called(1);
    });

    test('should clear reply after sending', () async {
      // Arrange
      replyToMessage = Message(
        id: 'original_msg',
        senderId: 'user456',
        type: MessageType.text,
        text: 'Original',
        timestamp: Timestamp.now(),
      );
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: 'Reply',
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: 'Reply',
        onSuccess: () {},
      );

      // Assert
      expect(replyClearCalled, isTrue);
      expect(replyToMessage, isNull);
    });

    test('should block message with profanity', () async {
      // Arrange
      bool successCalled = false;
      when(mockProfanityFilter.checkProfanitySync('fuck this', context: 'chat'))
          .thenReturn(ProfanityResult.found(
            word: 'fuck',
            language: 'en',
            severity: 'high',
            context: 'chat',
          ));

      // Act
      await handler.sendMessage(
        text: 'fuck this',
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isFalse);
      verifyNever(mockMessageRepository.sendMessage(any, any));
    });

    test('should call onSuccess callback after sending', () async {
      // Arrange
      bool successCalled = false;
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: 'Test message',
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: 'Test message',
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isTrue);
    });

    test('should trim whitespace from message text', () async {
      // Arrange
      const messageText = '  Hello  ';
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: messageText,
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: messageText,
        onSuccess: () {},
      );

      // Assert
      verify(mockMessageRepository.sendMessage(
        'room123',
        argThat(isA<Message>().having((m) => m.text, 'text', messageText)),
      )).called(1);
    });

    test('should not send if roomId is empty', () async {
      // Arrange
      final handlerNoRoom = MessageSendHandler(
        messageRepository: mockMessageRepository,
        roomId: '',
        itemScrollController: mockScrollController,
        getReplyToMessage: () => null,
        clearReply: () {},
        firebaseAuth: mockAuth,
      );
      bool successCalled = false;
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: 'Test',
            timestamp: Timestamp.now(),
          ));

      // Act
      await handlerNoRoom.sendMessage(
        text: 'Test',
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isFalse); // onSuccess should NOT be called
      verifyNever(mockMessageRepository.sendMessage(any, any));
    });

    test('should send message even if user not in Firebase', () async {
      // Arrange
      bool successCalled = false;
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: 'Test',
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: 'Test',
        onSuccess: () => successCalled = true,
      );

      // Assert
      expect(successCalled, isTrue);
      verify(mockMessageRepository.sendMessage(any, any)).called(1);
    });
  });

  group('Scroll Behavior', () {
    test('should scroll to bottom after sending message', () async {
      // Arrange
      when(mockScrollController.isAttached).thenReturn(true);
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: 'Test message',
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: 'Test message',
        onSuccess: () {},
      );

      // Wait for scroll delay
      await Future.delayed(const Duration(milliseconds: 900));

      // Assert
      verify(mockScrollController.scrollTo(
        index: 0,
        duration: anyNamed('duration'),
        curve: anyNamed('curve'),
      )).called(1);
    });

    test('should not scroll if controller not attached', () async {
      // Arrange
      when(mockScrollController.isAttached).thenReturn(false);
      when(mockMessageRepository.sendMessage(any, any))
          .thenAnswer((_) async => Message(
            id: 'id',
            senderId: 'user123',
            type: MessageType.text,
            text: 'Test message',
            timestamp: Timestamp.now(),
          ));

      // Act
      await handler.sendMessage(
        text: 'Test message',
        onSuccess: () {},
      );

      // Wait for scroll delay
      await Future.delayed(const Duration(milliseconds: 900));

      // Assert
      verifyNever(mockScrollController.scrollTo(
        index: anyNamed('index'),
        duration: anyNamed('duration'),
        curve: anyNamed('curve'),
      ));
    });
  });

  group('Error Handling', () {
    test('should handle send error gracefully', () async {
      // Arrange
      when(mockMessageRepository.sendMessage(any, any))
          .thenThrow(Exception('Network error'));

      // Act & Assert - should not throw
      await handler.sendMessage(
        text: 'Test',
        onSuccess: () {},
      );

      // Error is handled by ErrorHandler, message not sent
      verify(mockMessageRepository.sendMessage(any, any)).called(1);
    });
  });
}
