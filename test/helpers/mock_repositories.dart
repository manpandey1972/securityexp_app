import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/data/models/models.dart';

/// Mock implementation of FirestoreChatService for testing
class MockChatRepository extends Mock {
  Future<List<Room>> getUserRooms(String userId) async {
    return [
      Room(
        id: 'room1',
        participants: ['user1', 'user2'],
        lastMessage: 'Hello',
        lastMessageTime: Timestamp.now(),
        createdAt: Timestamp.now(),
      ),
    ];
  }

  Future<Message> sendChatMessage(String roomId, Message message) async {
    return message;
  }

  Future<String> getRoom(String userA, String userB) async {
    return 'room1';
  }

  Future<List<Message>> getRoomMessages(String roomId, {int limit = 50}) async {
    return [
      Message(
        id: 'msg1',
        senderId: 'user1',
        type: MessageType.text,
        text: 'Hello',
        timestamp: Timestamp.now(),
      ),
    ];
  }
}

/// Mock implementation of User repository for testing
class MockUserRepository extends Mock {
  Future<User?> getUser(String userId) async {
    return User(
      id: 'user1',
      name: 'Test User',
      email: 'user@example.com',
      phone: '+1234567890',
      roles: [],
      languages: [],
      expertises: [],
      fcmTokens: [],
      createdTime: Timestamp.now(),
      updatedTime: Timestamp.now(),
    );
  }

  Future<void> updateUser(User user) async {
    // Mock implementation
  }

  Future<void> deleteUser(String userId) async {
    // Mock implementation
  }
}

/// Mock implementation of Auth repository for testing
class MockAuthRepository extends Mock {
  Future<bool> login(String email, String password) async {
    if (email == 'valid@example.com' && password == 'password123') {
      return true;
    }
    throw Exception('Invalid credentials');
  }

  Future<bool> signUp(String email, String password, String name) async {
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      throw Exception('Missing required fields');
    }
    return true;
  }

  Future<void> logout() async {
    // Mock implementation
  }

  Future<String?> getCurrentUserId() async {
    return 'user1';
  }
}
