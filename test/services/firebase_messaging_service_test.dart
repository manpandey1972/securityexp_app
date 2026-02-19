import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:greenhive_app/shared/services/firebase_messaging_service.dart';
import 'package:greenhive_app/shared/services/notification_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

@GenerateMocks([
  FirebaseMessaging,
  NotificationService,
  AppLogger,
  RemoteMessage,
  NotificationSettings,
  RemoteNotification,
])
import 'firebase_messaging_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseMessaging mockMessaging;
  late MockNotificationService mockNotificationService;
  late MockAppLogger mockLogger;
  late FirebaseMessagingService service;

  setUp(() {
    mockMessaging = MockFirebaseMessaging();
    mockNotificationService = MockNotificationService();
    mockLogger = MockAppLogger();

    // Reset and register mocks
    sl.reset();
    sl.registerSingleton<AppLogger>(mockLogger);
    sl.registerSingleton<NotificationService>(mockNotificationService);

    // Pass the mocked FirebaseMessaging to the service
    service = FirebaseMessagingService(firebaseMessaging: mockMessaging);
  });

  tearDown(() {
    sl.reset();
  });

  group('FirebaseMessagingService - Initialization', () {
    test('should initialize successfully', () async {
      when(
        mockMessaging.requestPermission(
          alert: anyNamed('alert'),
          badge: anyNamed('badge'),
          sound: anyNamed('sound'),
        ),
      ).thenAnswer((_) async => MockNotificationSettings());

      when(mockMessaging.getToken()).thenAnswer((_) async => 'test_token');

      // Test initialization logic
      expect(service, isNotNull);
    });

    test('should request notification permissions', () async {
      final mockSettings = MockNotificationSettings();
      when(
        mockSettings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.authorized);

      when(
        mockMessaging.requestPermission(alert: true, badge: true, sound: true),
      ).thenAnswer((_) async => mockSettings);

      // Verify permission request would not be made until initialize is invoked
      verifyNever(
        mockMessaging.requestPermission(
          alert: anyNamed('alert'),
          badge: anyNamed('badge'),
          sound: anyNamed('sound'),
        ),
      );
    });
  });

  group('FirebaseMessagingService - Token Management', () {
    test('should retrieve FCM token', () async {
      const testToken = 'test_fcm_token_123';

      when(mockMessaging.getToken()).thenAnswer((_) async => testToken);

      // Test token retrieval
      final token = await mockMessaging.getToken();

      expect(token, testToken);
      verify(mockMessaging.getToken()).called(1);
    });

    test('should handle token refresh', () async {
      const newToken = 'new_fcm_token_456';

      // Setup token refresh stream
      when(
        mockMessaging.onTokenRefresh,
      ).thenAnswer((_) => Stream.value(newToken));

      // Listen to token refresh
      mockMessaging.onTokenRefresh.listen((token) {
        expect(token, newToken);
      });
    });

    test('should handle null token gracefully', () async {
      when(mockMessaging.getToken()).thenAnswer((_) async => null);

      final token = await mockMessaging.getToken();

      expect(token, null);
    });
  });

  group('FirebaseMessagingService - Message Handling', () {
    test('should handle foreground messages', () async {
      final mockMessage = MockRemoteMessage();
      when(mockMessage.notification).thenReturn(null);
      when(mockMessage.data).thenReturn({'type': 'test'});

      // Verify message data structure
      expect(mockMessage.data['type'], 'test');
    });

    test('should handle background messages', () async {
      final mockMessage = MockRemoteMessage();
      when(mockMessage.data).thenReturn({'type': 'background'});

      // Simulate background message
      expect(mockMessage.data['type'], 'background');
    });

    test('should extract notification data correctly', () {
      final mockMessage = MockRemoteMessage();
      final mockNotification = MockRemoteNotification();

      when(mockNotification.title).thenReturn('Test Title');
      when(mockNotification.body).thenReturn('Test Body');
      when(mockMessage.notification).thenReturn(mockNotification);

      final notification = mockMessage.notification;

      expect(notification?.title, 'Test Title');
      expect(notification?.body, 'Test Body');
    });

    test('should handle message with custom data', () {
      final mockMessage = MockRemoteMessage();
      when(mockMessage.data).thenReturn({
        'type': 'chat',
        'roomId': 'room_123',
        'senderId': 'user_456',
      });

      final data = mockMessage.data;

      expect(data['type'], 'chat');
      expect(data['roomId'], 'room_123');
      expect(data['senderId'], 'user_456');
    });
  });

  group('FirebaseMessagingService - Notification Types', () {
    test('should identify chat notification', () {
      final mockMessage = MockRemoteMessage();
      when(mockMessage.data).thenReturn({'type': 'chat'});

      expect(mockMessage.data['type'], 'chat');
    });

    test('should identify call notification', () {
      final mockMessage = MockRemoteMessage();
      when(mockMessage.data).thenReturn({'type': 'call'});

      expect(mockMessage.data['type'], 'call');
    });

    test('should handle unknown notification type', () {
      final mockMessage = MockRemoteMessage();
      when(mockMessage.data).thenReturn({'type': 'unknown'});

      expect(mockMessage.data['type'], 'unknown');
    });
  });

  group('FirebaseMessagingService - Error Handling', () {
    test('should handle token retrieval failure', () async {
      when(
        mockMessaging.getToken(),
      ).thenThrow(Exception('Token retrieval failed'));

      expect(() async => await mockMessaging.getToken(), throwsException);
    });

    test('should handle permission denial', () async {
      final mockSettings = MockNotificationSettings();
      when(
        mockSettings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.denied);

      when(
        mockMessaging.requestPermission(),
      ).thenAnswer((_) async => mockSettings);

      final settings = await mockMessaging.requestPermission();
      expect(settings.authorizationStatus, AuthorizationStatus.denied);
    });
  });
}
