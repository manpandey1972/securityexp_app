import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// Helper class to setup service locator for testing
class TestServiceLocatorHelper {
  static final GetIt _testGetIt = GetIt.instance;

  /// Initialize service locator with mock implementations for testing
  static Future<void> setupTestServiceLocator() async {
    // Clear any existing registrations
    if (_testGetIt.isRegistered<ChatService>()) {
      _testGetIt.unregister<ChatService>();
    }

    // Register mock repositories
    _testGetIt.registerSingleton<MockChatRepository>(MockChatRepository());

    // Register validators (use real implementations for validators)
    _testGetIt.registerSingleton<EmailValidator>(EmailValidator());
    _testGetIt.registerSingleton<PhoneValidator>(PhoneValidator());
    _testGetIt.registerSingleton<MessageValidator>(MessageValidator());
    _testGetIt.registerSingleton<InputSanitizer>(InputSanitizer());
  }

  /// Get the test instance of GetIt
  static GetIt get testGetIt => _testGetIt;

  /// Reset service locator after tests
  static Future<void> resetTestServiceLocator() async {
    if (_testGetIt.isRegistered<ChatService>()) {
      _testGetIt.unregister<ChatService>();
    }
    if (_testGetIt.isRegistered<MockChatRepository>()) {
      _testGetIt.unregister<MockChatRepository>();
    }
    if (_testGetIt.isRegistered<EmailValidator>()) {
      _testGetIt.unregister<EmailValidator>();
    }
    if (_testGetIt.isRegistered<PhoneValidator>()) {
      _testGetIt.unregister<PhoneValidator>();
    }
    if (_testGetIt.isRegistered<MessageValidator>()) {
      _testGetIt.unregister<MessageValidator>();
    }
    if (_testGetIt.isRegistered<InputSanitizer>()) {
      _testGetIt.unregister<InputSanitizer>();
    }
  }
}

/// Mock classes for testing
class MockChatService extends Mock implements ChatService {}

class MockAuthService extends Mock implements AuthService {}

class MockUserProfileService extends Mock implements UserProfileService {}

class MockNotificationService extends Mock implements NotificationService {}

// Import stubs for entity types
class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.createdAt,
  });
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String status;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.status,
  });
}

// Service stubs
class ChatService {}

class AuthService {}

class UserProfileService {}

class NotificationService {}

// Validator imports for test
class EmailValidator {}

class PhoneValidator {}

class MessageValidator {}

class InputSanitizer {}

// Repository mock
class MockChatRepository extends Mock {}
