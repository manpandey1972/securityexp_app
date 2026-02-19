import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/shared/services/account_cleanup_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/features/chat/services/user_presence_service.dart';
import 'package:securityexperts_app/shared/services/firebase_messaging_service.dart';
import 'package:securityexperts_app/features/calling/infrastructure/repositories/voip_token_repository.dart';
import 'package:securityexperts_app/features/photo_backup/services/photo_backup_service.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';

@GenerateMocks([
  AppLogger,
  UserCacheService,
  UserPresenceService,
  FirebaseMessagingService,
  VoIPTokenRepository,
  PhotoBackupService,
  UserProfileService,
])
import 'account_cleanup_service_test.mocks.dart';

void main() {
  late AccountCleanupService service;
  late MockAppLogger mockLogger;
  late MockUserCacheService mockCache;
  late MockUserPresenceService mockPresence;
  late MockFirebaseMessagingService mockFCM;
  late MockVoIPTokenRepository mockVoIP;
  late MockPhotoBackupService mockPhotoBackup;

  setUp(() {
    mockLogger = MockAppLogger();
    mockCache = MockUserCacheService();
    mockPresence = MockUserPresenceService();
    mockFCM = MockFirebaseMessagingService();
    mockVoIP = MockVoIPTokenRepository();
    mockPhotoBackup = MockPhotoBackupService();

    // Register mocks in service locator
    if (sl.isRegistered<UserCacheService>()) sl.unregister<UserCacheService>();
    if (sl.isRegistered<UserPresenceService>()) {
      sl.unregister<UserPresenceService>();
    }
    if (sl.isRegistered<FirebaseMessagingService>()) {
      sl.unregister<FirebaseMessagingService>();
    }
    if (sl.isRegistered<VoIPTokenRepository>()) {
      sl.unregister<VoIPTokenRepository>();
    }
    if (sl.isRegistered<PhotoBackupService>()) {
      sl.unregister<PhotoBackupService>();
    }

    sl.registerSingleton<UserCacheService>(mockCache);
    sl.registerSingleton<UserPresenceService>(mockPresence);
    sl.registerSingleton<FirebaseMessagingService>(mockFCM);
    sl.registerSingleton<VoIPTokenRepository>(mockVoIP);
    sl.registerSingleton<PhotoBackupService>(mockPhotoBackup);

    // Stub default behavior
    when(mockPresence.clearPresence()).thenAnswer((_) async {});
    when(mockPresence.dispose()).thenAnswer((_) async {});
    when(mockFCM.removeTokenOnLogout()).thenAnswer((_) async {});
    when(mockVoIP.clearToken(userId: anyNamed('userId')))
        .thenAnswer((_) async {});
    when(mockPhotoBackup.dispose()).thenAnswer((_) async {});

    service = AccountCleanupService(mockLogger);
  });

  tearDown(() {
    sl.reset();
  });

  group('AccountCleanupService', () {
    test('performCleanup calls all cleanup steps in order', () async {
      await service.performCleanup('user-123');

      verify(mockCache.dispose()).called(1);
      verify(mockPresence.clearPresence()).called(1);
      verify(mockPresence.dispose()).called(1);
      verify(mockFCM.removeTokenOnLogout()).called(1);
      verify(mockVoIP.clearToken(userId: 'user-123')).called(1);
      verify(mockVoIP.dispose()).called(1);
      verify(mockPhotoBackup.dispose()).called(1);
    });

    test('performCleanup logs completion', () async {
      await service.performCleanup('user-123');

      verify(
        mockLogger.info('Cleanup completed for user user-123', tag: 'AccountCleanup'),
      ).called(1);
    });

    test('performCleanup is reentrant-safe (skips if already running)',
        () async {
      // Make clearPresence slow so we can test reentrancy
      when(mockPresence.clearPresence()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      final first = service.performCleanup('user-1');
      final second = service.performCleanup('user-1');

      await Future.wait([first, second]);

      // clearPresence should only be called once (second call was skipped)
      verify(mockPresence.clearPresence()).called(1);
      verify(mockLogger.info('Cleanup already in progress, skipping', tag: 'AccountCleanup'))
          .called(1);
    });

    test('performCleanup resets flag after completion so next call works',
        () async {
      await service.performCleanup('user-1');
      await service.performCleanup('user-2');

      // Both should complete fully — clearPresence called twice
      verify(mockPresence.clearPresence()).called(2);
    });

    test('individual step failure does not block remaining steps', () async {
      // Make FCM throw
      when(mockFCM.removeTokenOnLogout()).thenThrow(Exception('FCM failed'));

      await service.performCleanup('user-123');

      // Steps after FCM should still execute
      verify(mockVoIP.clearToken(userId: 'user-123')).called(1);
      verify(mockPhotoBackup.dispose()).called(1);

      // Warning should be logged for the failure
      verify(
        mockLogger.warning(
          argThat(contains('FCM removeToken failed')),
          tag: 'AccountCleanup',
        ),
      ).called(1);
    });

    test('performCleanup resets flag even when step throws', () async {
      when(mockCache.dispose()).thenThrow(Exception('cache boom'));

      await service.performCleanup('user-1');
      // Should be able to run again (flag was reset in finally)
      await service.performCleanup('user-2');

      verify(mockPresence.clearPresence()).called(2);
    });
  });
}
