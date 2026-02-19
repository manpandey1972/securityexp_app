import 'package:flutter_test/flutter_test.dart';
import 'package:greenhive_app/data/repositories/chat/chat_room_repository.dart';

/// Unit tests for ChatRoomRepository
///
/// Note: Integration tests with FakeFirebaseFirestore require additional setup
/// due to ErrorHandler dependencies. These tests focus on testable static methods
/// and exception handling.
void main() {
  group('ChatRoomRepository', () {
    group('generateRoomId', () {
      test('should generate consistent room ID regardless of user order', () {
        // Act - static method, no repository needed
        final roomId1 = ChatRoomRepository.generateRoomId('user1', 'user2');
        final roomId2 = ChatRoomRepository.generateRoomId('user2', 'user1');

        // Assert
        expect(roomId1, equals(roomId2));
        expect(roomId1, equals('user1_user2'));
      });

      test('should sort user IDs alphabetically', () {
        // Act
        final roomId = ChatRoomRepository.generateRoomId('zack', 'alice');

        // Assert
        expect(roomId, equals('alice_zack'));
      });

      test('should handle identical prefixed user IDs correctly', () {
        // Act
        final roomId = ChatRoomRepository.generateRoomId('user10', 'user1');

        // Assert - user1 comes before user10 alphabetically
        expect(roomId, equals('user1_user10'));
      });

      test('should handle special characters in user IDs', () {
        // Act
        final roomId = ChatRoomRepository.generateRoomId('user_a', 'user_b');

        // Assert
        expect(roomId, equals('user_a_user_b'));
      });

      test('should handle numeric user IDs', () {
        // Act
        final roomId1 = ChatRoomRepository.generateRoomId('123', '456');
        final roomId2 = ChatRoomRepository.generateRoomId('456', '123');

        // Assert
        expect(roomId1, equals(roomId2));
        expect(roomId1, equals('123_456'));
      });
    });

    group('ChatRoomException', () {
      test('should create exception with message', () {
        // Act
        final exception = ChatRoomException('Test error message');

        // Assert
        expect(exception.message, equals('Test error message'));
        expect(exception.toString(), contains('Test error message'));
      });

      test('should be throwable', () {
        // Act & Assert
        expect(
          () => throw ChatRoomException('Thrown error'),
          throwsA(isA<ChatRoomException>()),
        );
      });

      test('should contain message in toString', () {
        // Act
        final exception = ChatRoomException('Custom message');

        // Assert
        expect(
          exception.toString(),
          equals('ChatRoomException: Custom message'),
        );
      });
    });

    group('Room ID format validation', () {
      test('should use underscore as separator', () {
        // Act
        final roomId = ChatRoomRepository.generateRoomId('aaa', 'bbb');

        // Assert
        expect(roomId.contains('_'), isTrue);
        expect(roomId.split('_').length, equals(2));
      });

      test('should produce deterministic IDs', () {
        // Act - call multiple times
        final results = <String>[];
        for (var i = 0; i < 10; i++) {
          results.add(ChatRoomRepository.generateRoomId('userA', 'userB'));
        }

        // Assert - all results should be identical
        expect(results.toSet().length, equals(1));
      });
    });
  });
}
