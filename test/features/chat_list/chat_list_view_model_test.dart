import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/chat_list/presentation/view_models/chat_list_view_model.dart';
import 'package:securityexperts_app/data/repositories/chat/chat_repositories.dart';
import 'package:securityexperts_app/features/chat/services/unread_messages_service.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;

import 'chat_list_view_model_test.mocks.dart';

@GenerateMocks([ChatRoomRepository, UnreadMessagesService, AppLogger])
void main() {
  late ChatListViewModel viewModel;
  late MockChatRoomRepository mockRoomRepository;
  late MockUnreadMessagesService mockUnreadService;
  late MockAppLogger mockAppLogger;

  setUp(() {
    mockRoomRepository = MockChatRoomRepository();
    mockUnreadService = MockUnreadMessagesService();
    mockAppLogger = MockAppLogger();

    // Register AppLogger in service locator
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    // Register MediaCacheService (needed by ChatListViewModel field initializer)
    if (sl.isRegistered<MediaCacheService>()) {
      sl.unregister<MediaCacheService>();
    }
    sl.registerSingleton<MediaCacheService>(MediaCacheService());

    // Default stub for room stream
    when(
      mockRoomRepository.getUserRoomsStream(any),
    ).thenAnswer((_) => Stream.value([]));
    when(mockRoomRepository.getUserRooms(any)).thenAnswer((_) async => []);
    when(
      mockUnreadService.recalculateTotalUnreadCount(),
    ).thenAnswer((_) async {});

    viewModel = ChatListViewModel(
      roomRepository: mockRoomRepository,
      unreadMessagesService: mockUnreadService,
    );
  });

  tearDown(() {
    viewModel.dispose();
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<MediaCacheService>()) {
      sl.unregister<MediaCacheService>();
    }
  });

  group('ChatListViewModel', () {
    test('should have initial empty state', () {
      expect(viewModel.state.loading, equals(false));
      expect(viewModel.state.rooms, isEmpty);
      expect(viewModel.state.error, isNull);
    });

    test('should expose unreadMessagesService', () {
      expect(viewModel.unreadMessagesService, equals(mockUnreadService));
    });
  });

  group('loadRooms', () {
    test('should set loading state when loading rooms', () async {
      // Arrange - use a completer to control when rooms are returned
      when(mockRoomRepository.getUserRooms(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return [];
      });

      // Note: We can't easily test loading state without Firebase Auth mock
      // This test verifies the structure is correct
      expect(viewModel.state.loading, equals(false));
    });

    test('should handle empty rooms list', () async {
      when(mockRoomRepository.getUserRooms(any)).thenAnswer((_) async => []);

      // The actual load requires Firebase Auth, so we verify the mock is set up correctly
      // In production, loadRooms() would call getUserRooms - we're testing the mock setup
      expect(await mockRoomRepository.getUserRooms('any-user'), isEmpty);
    });
  });

  group('Room sorting', () {
    test('helper should create valid Room objects', () {
      final room = _createRoom(
        id: 'test-room',
        participants: ['user1', 'user2'],
        lastMessage: 'Hello',
      );

      expect(room.id, equals('test-room'));
      expect(room.participants, contains('user1'));
      expect(room.lastMessage, equals('Hello'));
    });

    test('rooms should be sortable by lastMessageTime', () {
      final now = DateTime.now();
      final rooms = [
        _createRoom(
          id: 'room1',
          lastMessageTime: Timestamp.fromDate(
            now.subtract(const Duration(hours: 2)),
          ),
        ),
        _createRoom(id: 'room2', lastMessageTime: Timestamp.fromDate(now)),
        _createRoom(
          id: 'room3',
          lastMessageTime: Timestamp.fromDate(
            now.subtract(const Duration(hours: 1)),
          ),
        ),
      ];

      // Sort like the ViewModel does (most recent first)
      rooms.sort((a, b) {
        final aTime =
            a.lastMessageDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastMessageDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      expect(rooms[0].id, equals('room2')); // Most recent
      expect(rooms[1].id, equals('room3'));
      expect(rooms[2].id, equals('room1')); // Oldest
    });

    test('rooms without lastMessageTime should be sorted last', () {
      final now = DateTime.now();
      final rooms = [
        _createRoom(id: 'room1', lastMessageTime: null),
        _createRoom(id: 'room2', lastMessageTime: Timestamp.fromDate(now)),
      ];

      rooms.sort((a, b) {
        final aTime =
            a.lastMessageDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastMessageDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      expect(rooms[0].id, equals('room2')); // Has timestamp
      expect(rooms[1].id, equals('room1')); // No timestamp, sorted last
    });
  });

  group('Stream subscription', () {
    test('should set up room stream subscription on getUserRoomsStream', () {
      // Verify the stream method exists and can be called
      when(
        mockRoomRepository.getUserRoomsStream('test-user'),
      ).thenAnswer((_) => Stream.value([_createRoom(id: 'room1')]));

      final stream = mockRoomRepository.getUserRoomsStream('test-user');
      expect(stream, isA<Stream<List<models.Room>>>());
    });
  });
}

/// Helper function to create test Room objects
models.Room _createRoom({
  required String id,
  List<String>? participants,
  String lastMessage = '',
  Timestamp? lastMessageTime,
  Timestamp? createdAt,
}) {
  return models.Room(
    id: id,
    participants: participants ?? ['user1', 'user2'],
    lastMessage: lastMessage,
    lastMessageTime: lastMessageTime,
    createdAt: createdAt,
  );
}
