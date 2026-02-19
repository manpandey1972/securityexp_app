import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:greenhive_app/features/chat/services/user_presence_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

@GenerateMocks([
  FirebaseDatabase,
  firebase_auth.FirebaseAuth,
  firebase_auth.User,
  DatabaseReference,
  OnDisconnect,
  AppLogger,
])
import 'user_presence_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserPresenceService presenceService;
  late MockFirebaseDatabase mockDatabase;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockAppLogger mockLogger;
  late MockDatabaseReference mockPresenceRef;
  late MockDatabaseReference mockConnectedRef;
  late MockOnDisconnect mockOnDisconnect;

  const testUserId = 'test-user-123';
  const testRoomId = 'test-room-456';

  setUp(() {
    mockDatabase = MockFirebaseDatabase();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockLogger = MockAppLogger();
    mockPresenceRef = MockDatabaseReference();
    mockConnectedRef = MockDatabaseReference();
    mockOnDisconnect = MockOnDisconnect();

    // Setup auth mock
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn(testUserId);

    // Setup database references
    when(mockDatabase.ref('presence/$testUserId')).thenReturn(mockPresenceRef);
    when(mockDatabase.ref('.info/connected')).thenReturn(mockConnectedRef);
    when(mockPresenceRef.onDisconnect()).thenReturn(mockOnDisconnect);

    // Setup default stubs for common operations
    when(mockPresenceRef.update(any)).thenAnswer((_) async {});
    when(mockPresenceRef.set(any)).thenAnswer((_) async {});
    when(mockOnDisconnect.set(any)).thenAnswer((_) async {});
    when(mockOnDisconnect.cancel()).thenAnswer((_) async {});

    presenceService = UserPresenceService(
      database: mockDatabase,
      auth: mockAuth,
      logger: mockLogger,
    );
  });

  group('UserPresenceService', () {
    group('initialization', () {
      test('should not be initialized by default', () {
        expect(presenceService.isInitialized, false);
        expect(presenceService.currentChatRoomId, isNull);
      });

      test('should not initialize without authenticated user', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        final serviceWithoutUser = UserPresenceService(
          database: mockDatabase,
          auth: mockAuth,
          logger: mockLogger,
        );

        // Act
        await serviceWithoutUser.initialize();

        // Assert
        expect(serviceWithoutUser.isInitialized, false);
        verify(mockLogger.warning(any, tag: 'UserPresenceService')).called(1);
      });
    });

    group('enterChatRoom', () {
      test('should update currentChatRoomId', () async {
        // Act
        await presenceService.enterChatRoom(testRoomId);

        // Assert
        expect(presenceService.currentChatRoomId, testRoomId);
        verify(mockLogger.debug('Entered chat room: $testRoomId', tag: 'UserPresenceService')).called(1);
      });

      test('should allow changing chat rooms', () async {
        // Act
        await presenceService.enterChatRoom('room1');
        await presenceService.enterChatRoom('room2');

        // Assert
        expect(presenceService.currentChatRoomId, 'room2');
      });

      test('should handle multiple room enters', () async {
        // Act
        await presenceService.enterChatRoom('room1');
        expect(presenceService.currentChatRoomId, 'room1');

        await presenceService.enterChatRoom('room2');
        expect(presenceService.currentChatRoomId, 'room2');

        await presenceService.enterChatRoom('room3');
        expect(presenceService.currentChatRoomId, 'room3');
      });
    });

    group('leaveChatRoom', () {
      test('should clear currentChatRoomId', () async {
        // Arrange
        await presenceService.enterChatRoom(testRoomId);
        expect(presenceService.currentChatRoomId, testRoomId);

        // Act
        await presenceService.leaveChatRoom();

        // Assert
        expect(presenceService.currentChatRoomId, isNull);
      });

      test('should log previous room', () async {
        // Arrange
        await presenceService.enterChatRoom(testRoomId);

        // Act
        await presenceService.leaveChatRoom();

        // Assert
        verify(mockLogger.debug('Left chat room: $testRoomId', tag: 'UserPresenceService')).called(1);
      });

      test('should handle leaving when not in a room', () async {
        // Act
        await presenceService.leaveChatRoom();

        // Assert
        expect(presenceService.currentChatRoomId, isNull);
        verify(mockLogger.debug('Left chat room: null', tag: 'UserPresenceService')).called(1);
      });
    });

    group('setAppInForeground', () {
      test('should log foreground state', () async {
        // Act
        await presenceService.setAppInForeground();

        // Assert
        verify(mockLogger.debug('App in foreground', tag: 'UserPresenceService')).called(1);
      });
    });

    group('setAppInBackground', () {
      test('should log background state with null room info', () async {
        // Act
        await presenceService.setAppInBackground();

        // Assert
        verify(mockLogger.debug('App in background, chatRoom=null', tag: 'UserPresenceService')).called(1);
      });

      test('should log background state with room info', () async {
        // Arrange
        await presenceService.enterChatRoom(testRoomId);

        // Act
        await presenceService.setAppInBackground();

        // Assert
        verify(mockLogger.debug('App in background, chatRoom=$testRoomId', tag: 'UserPresenceService')).called(1);
      });

      test('should preserve currentChatRoomId when backgrounded', () async {
        // Arrange
        await presenceService.enterChatRoom(testRoomId);

        // Act
        await presenceService.setAppInBackground();

        // Assert - room should still be set
        expect(presenceService.currentChatRoomId, testRoomId);
      });
    });

    group('clearPresence', () {
      test('should cancel onDisconnect and set offline', () async {
        // Act
        await presenceService.clearPresence();

        // Assert
        verify(mockOnDisconnect.cancel()).called(1);
        verify(mockPresenceRef.set(argThat(predicate((arg) {
          return arg is Map && arg['isOnline'] == false && arg['currentChatRoomId'] == null;
        })))).called(1);
      });

      test('should handle error gracefully', () async {
        // Arrange
        when(mockOnDisconnect.cancel()).thenThrow(Exception('Network error'));

        // Act
        await presenceService.clearPresence();

        // Assert
        verify(mockLogger.error(any, tag: 'UserPresenceService')).called(1);
      });

      test('should warn when no userId available', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);
        final serviceWithoutUser = UserPresenceService(
          database: mockDatabase,
          auth: mockAuth,
          logger: mockLogger,
        );

        // Act
        await serviceWithoutUser.clearPresence();

        // Assert
        verify(mockLogger.warning(any, tag: 'UserPresenceService')).called(1);
      });
    });

    group('dispose', () {
      test('should reset all state', () async {
        // Arrange
        await presenceService.enterChatRoom(testRoomId);

        // Act
        await presenceService.dispose();

        // Assert
        expect(presenceService.isInitialized, false);
        expect(presenceService.currentChatRoomId, isNull);
        verify(mockLogger.debug('UserPresenceService disposed', tag: 'UserPresenceService')).called(1);
      });

      test('should be safe to call multiple times', () async {
        // Act
        await presenceService.dispose();
        await presenceService.dispose();

        // Assert - should log twice
        verify(mockLogger.debug('UserPresenceService disposed', tag: 'UserPresenceService')).called(2);
      });
    });

    group('integration scenarios', () {
      test('should handle full lifecycle: enter -> background -> foreground -> leave', () async {
        // Enter room
        await presenceService.enterChatRoom(testRoomId);
        expect(presenceService.currentChatRoomId, testRoomId);

        // Go to background
        await presenceService.setAppInBackground();
        expect(presenceService.currentChatRoomId, testRoomId); // Room preserved

        // Return to foreground
        await presenceService.setAppInForeground();
        expect(presenceService.currentChatRoomId, testRoomId); // Still in room

        // Leave room
        await presenceService.leaveChatRoom();
        expect(presenceService.currentChatRoomId, isNull);
      });

      test('should handle rapid room switching', () async {
        for (int i = 0; i < 5; i++) {
          await presenceService.enterChatRoom('room-$i');
          expect(presenceService.currentChatRoomId, 'room-$i');
        }

        await presenceService.leaveChatRoom();
        expect(presenceService.currentChatRoomId, isNull);
      });
    });
  });
}
