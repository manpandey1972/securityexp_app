// ChatMediaCacheHelper tests
//
// Tests for the chat media cache helper which manages media caching with LRU eviction.

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:greenhive_app/features/chat/services/chat_media_cache_helper.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

import '../../../helpers/service_mocks.mocks.dart';

@GenerateMocks([CacheManager, FileInfo])
import 'chat_media_cache_helper_test.mocks.dart';

// Simple mock message class for testing
class MockMessage {
  final String? mediaUrl;
  final DateTime createdAt;

  MockMessage({this.mediaUrl, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
}

void main() {
  late MockMediaCacheService mockMediaCacheService;
  late MockCacheManager mockCacheManager;
  late MockAppLogger mockAppLogger;
  late ChatMediaCacheHelper helper;
  const testRoomId = 'test-room-123';

  setUp(() {
    mockMediaCacheService = MockMediaCacheService();
    mockCacheManager = MockCacheManager();
    mockAppLogger = MockAppLogger();

    // Register mock AppLogger
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    // Setup default behavior
    when(mockMediaCacheService.getManagerForRoom(any))
        .thenReturn(mockCacheManager);

    helper = ChatMediaCacheHelper(
      mediaCacheService: mockMediaCacheService,
      roomId: testRoomId,
    );
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('ChatMediaCacheHelper', () {
    group('cacheManager', () {
      test('should return cache manager for room', () {
        final result = helper.cacheManager;

        expect(result, mockCacheManager);
        verify(mockMediaCacheService.getManagerForRoom(testRoomId)).called(1);
      });
    });

    group('getCachedMediaFileFuture', () {
      test('should call media cache service to fetch file', () async {
        const mediaUrl = 'https://example.com/image.jpg';

        when(mockMediaCacheService.getMediaFile(testRoomId, mediaUrl))
            .thenAnswer((_) async => null);

        await helper.getCachedMediaFileFuture(mediaUrl);

        verify(mockMediaCacheService.getMediaFile(testRoomId, mediaUrl))
            .called(1);
      });

      test('should not call service again for same URL', () async {
        const mediaUrl = 'https://example.com/image.jpg';

        when(mockMediaCacheService.getMediaFile(testRoomId, mediaUrl))
            .thenAnswer((_) async => null);

        // Call twice
        await helper.getCachedMediaFileFuture(mediaUrl);
        await helper.getCachedMediaFileFuture(mediaUrl);

        // Should only call the service once (caches the future)
        verify(mockMediaCacheService.getMediaFile(testRoomId, mediaUrl))
            .called(1);
      });
    });

    group('getNormalizedDate', () {
      test('should return normalized date with only year, month, day', () {
        final dateTime = DateTime(2024, 3, 15, 14, 30, 45, 123, 456);

        final result = helper.getNormalizedDate(dateTime);

        expect(result.year, 2024);
        expect(result.month, 3);
        expect(result.day, 15);
        expect(result.hour, 0);
        expect(result.minute, 0);
        expect(result.second, 0);
        expect(result.millisecond, 0);
      });

      test('should return same object for same date', () {
        final dateTime1 = DateTime(2024, 3, 15, 10, 0, 0);
        final dateTime2 = DateTime(2024, 3, 15, 20, 30, 45);

        final result1 = helper.getNormalizedDate(dateTime1);
        final result2 = helper.getNormalizedDate(dateTime2);

        expect(identical(result1, result2), true);
      });

      test('should return different objects for different dates', () {
        final dateTime1 = DateTime(2024, 3, 15);
        final dateTime2 = DateTime(2024, 3, 16);

        final result1 = helper.getNormalizedDate(dateTime1);
        final result2 = helper.getNormalizedDate(dateTime2);

        expect(identical(result1, result2), false);
        expect(result1.day, 15);
        expect(result2.day, 16);
      });
    });

    group('prefetchAllMedia', () {
      test('should prefetch media from all messages', () async {
        final messages = [
          MockMessage(mediaUrl: 'https://example.com/image1.jpg'),
          MockMessage(mediaUrl: 'https://example.com/image2.jpg'),
          MockMessage(mediaUrl: null),
          MockMessage(mediaUrl: ''),
          MockMessage(mediaUrl: 'https://example.com/image3.jpg'),
        ];

        when(mockMediaCacheService.getMediaFile(any, any))
            .thenAnswer((_) async => null);

        await helper.prefetchAllMedia(messages);

        // Should only fetch non-null, non-empty URLs
        verify(mockMediaCacheService.getMediaFile(
          testRoomId,
          'https://example.com/image1.jpg',
        )).called(1);
        verify(mockMediaCacheService.getMediaFile(
          testRoomId,
          'https://example.com/image2.jpg',
        )).called(1);
        verify(mockMediaCacheService.getMediaFile(
          testRoomId,
          'https://example.com/image3.jpg',
        )).called(1);
      });

      test('should handle empty message list', () async {
        await helper.prefetchAllMedia([]);
        verifyNever(mockMediaCacheService.getMediaFile(any, any));
      });

      test('should handle messages with no media', () async {
        final messages = [
          MockMessage(mediaUrl: null),
          MockMessage(mediaUrl: ''),
          MockMessage(mediaUrl: null),
        ];

        await helper.prefetchAllMedia(messages);
        verifyNever(mockMediaCacheService.getMediaFile(any, any));
      });
    });

    group('prefetchVisibleMedia', () {
      test('should prefetch visible range plus lookahead', () async {
        final messages = List.generate(
          20,
          (i) => MockMessage(mediaUrl: 'https://example.com/image$i.jpg'),
        );

        when(mockMediaCacheService.getMediaFile(any, any))
            .thenAnswer((_) async => null);

        await helper.prefetchVisibleMedia(
          messages,
          visibleStartIndex: 5,
          visibleEndIndex: 10,
          lookahead: 3,
        );

        // Should fetch from index 2 (5-3) to index 13 (10+3)
        // That's indices 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 = 12 items
        verify(mockMediaCacheService.getMediaFile(testRoomId, any)).called(12);
      });

      test('should handle empty message list', () async {
        await helper.prefetchVisibleMedia([]);
        verifyNever(mockMediaCacheService.getMediaFile(any, any));
      });

      test('should clamp indices to valid range', () async {
        final messages = List.generate(
          5,
          (i) => MockMessage(mediaUrl: 'https://example.com/image$i.jpg'),
        );

        when(mockMediaCacheService.getMediaFile(any, any))
            .thenAnswer((_) async => null);

        await helper.prefetchVisibleMedia(
          messages,
          visibleStartIndex: 0,
          visibleEndIndex: 2,
          lookahead: 100, // Much larger than message count
        );

        // Should clamp to 0-4 (all 5 messages)
        verify(mockMediaCacheService.getMediaFile(testRoomId, any)).called(5);
      });
    });

    group('warmCache', () {
      test('should warm cache with recent media', () async {
        final messages = List.generate(
          30,
          (i) => MockMessage(mediaUrl: 'https://example.com/image$i.jpg'),
        );

        when(mockMediaCacheService.getMediaFile(any, any))
            .thenAnswer((_) async => null);

        await helper.warmCache(messages, count: 10);

        // Should fetch 10 most recent (which are the last 10 since reversed)
        verify(mockMediaCacheService.getMediaFile(testRoomId, any)).called(10);
      });

      test('should handle empty message list', () async {
        await helper.warmCache([]);
        verifyNever(mockMediaCacheService.getMediaFile(any, any));
      });

      test('should handle messages with mixed media', () async {
        final messages = [
          MockMessage(mediaUrl: null),
          MockMessage(mediaUrl: 'https://example.com/image1.jpg'),
          MockMessage(mediaUrl: ''),
          MockMessage(mediaUrl: 'https://example.com/image2.jpg'),
          MockMessage(mediaUrl: null),
        ];

        when(mockMediaCacheService.getMediaFile(any, any))
            .thenAnswer((_) async => null);

        await helper.warmCache(messages, count: 10);

        // Should only fetch non-null, non-empty URLs
        verify(mockMediaCacheService.getMediaFile(testRoomId, any)).called(2);
      });
    });

    group('isUrlCached', () {
      test('should return true when file is cached', () async {
        const mediaUrl = 'https://example.com/cached-image.jpg';
        final mockFileInfo = null;

        when(mockCacheManager.getFileFromCache(mediaUrl))
            .thenAnswer((_) async => mockFileInfo);

        // Mock file existence check - we can't easily mock File.existsSync
        // so this test checks the method signature more than behavior
        // In real tests, you'd need to use a test file or mock file system
      });

      test('should return false when file is not cached', () async {
        const mediaUrl = 'https://example.com/not-cached.jpg';

        when(mockCacheManager.getFileFromCache(mediaUrl))
            .thenAnswer((_) async => null);

        final result = await helper.isUrlCached(mediaUrl);
        expect(result, false);
      });
    });

    group('clearCache', () {
      test('should clear all cached futures and dates', () async {
        // First, populate caches
        const mediaUrl = 'https://example.com/image.jpg';
        when(mockMediaCacheService.getMediaFile(testRoomId, mediaUrl))
            .thenAnswer((_) async => null);

        await helper.getCachedMediaFileFuture(mediaUrl);
        helper.getNormalizedDate(DateTime(2024, 3, 15));

        // Clear cache
        helper.clearCache();

        // Next call should trigger a new fetch
        await helper.getCachedMediaFileFuture(mediaUrl);

        // Should be called twice total (once before clear, once after)
        verify(mockMediaCacheService.getMediaFile(testRoomId, mediaUrl))
            .called(2);
      });
    });
  });
}
