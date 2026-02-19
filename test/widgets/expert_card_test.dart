import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:greenhive_app/features/home/widgets/expert_card.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

@GenerateMocks([AppLogger])
import 'expert_card_test.mocks.dart';

void main() {
  late MockAppLogger mockLogger;

  setUp(() {
    mockLogger = MockAppLogger();

    // Register service locator dependencies
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockLogger);
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('ExpertCard', () {
    late User testExpert;

    setUp(() {
      testExpert = User(
        id: 'expert_123',
        name: 'Dr. John Doe',
        email: 'john@example.com',
        roles: ['Expert'],
        languages: ['English', 'Spanish'],
        expertises: ['Agriculture', 'Sustainability'],
        fcmTokens: [],
        bio: 'Expert in sustainable farming',
        profilePictureUrl: 'https://example.com/profile.jpg',
        notificationsEnabled: true,
      );
    });

    // Constructor and property tests (unit tests, not widget tests)
    test('should create with required parameters', () {
      final card = ExpertCard(
        expert: testExpert,
        skillNames: ['Agriculture', 'Sustainability'],
      );

      expect(card.expert, testExpert);
      expect(card.skillNames, ['Agriculture', 'Sustainability']);
      expect(card.enableActions, true);
      expect(card.showProfilePicture, true);
    });

    test('should have default values for optional parameters', () {
      final card = ExpertCard(expert: testExpert);

      expect(card.skillNames, []);
      expect(card.onChat, isNull);
      expect(card.onAudioCall, isNull);
      expect(card.onVideoCall, isNull);
      expect(card.onTap, isNull);
      expect(card.showProfilePicture, true);
      expect(card.profilePictureSize, 56);
      expect(card.elevation, 0);
      expect(card.enableActions, true);
    });

    test('should accept custom elevation', () {
      final card = ExpertCard(
        expert: testExpert,
        skillNames: ['Agriculture'],
        elevation: 8.0,
      );

      expect(card.elevation, 8.0);
    });

    test('should accept custom profilePictureSize', () {
      final card = ExpertCard(
        expert: testExpert,
        profilePictureSize: 80,
      );

      expect(card.profilePictureSize, 80);
    });

    test('should accept callbacks', () {
      var chatCalled = false;
      var audioCalled = false;
      var videoCalled = false;
      var tapCalled = false;

      final card = ExpertCard(
        expert: testExpert,
        onChat: (id, name) => chatCalled = true,
        onAudioCall: (id, name) => audioCalled = true,
        onVideoCall: (id, name) => videoCalled = true,
        onTap: () => tapCalled = true,
      );

      card.onChat?.call('123', 'John');
      expect(chatCalled, true);

      card.onAudioCall?.call('123', 'John');
      expect(audioCalled, true);

      card.onVideoCall?.call('123', 'John');
      expect(videoCalled, true);

      card.onTap?.call();
      expect(tapCalled, true);
    });

    test('should accept disable actions flag', () {
      final card = ExpertCard(
        expert: testExpert,
        enableActions: false,
      );

      expect(card.enableActions, false);
    });

    test('should accept disable profile picture flag', () {
      final card = ExpertCard(
        expert: testExpert,
        showProfilePicture: false,
      );

      expect(card.showProfilePicture, false);
    });

    test('should handle empty skillNames', () {
      final card = ExpertCard(
        expert: testExpert,
        skillNames: [],
      );

      expect(card.skillNames, isEmpty);
    });

    test('should handle user without bio', () {
      final expertNoBio = User(
        id: 'expert_456',
        name: 'Jane Smith',
        email: 'jane@example.com',
        roles: ['Expert'],
        languages: ['English'],
        expertises: ['Technology'],
        fcmTokens: [],
        bio: null,
        notificationsEnabled: true,
      );

      final card = ExpertCard(
        expert: expertNoBio,
        skillNames: ['Technology'],
      );

      expect(card.expert.bio, isNull);
    });

    test('should handle expert without expertises', () {
      final expertNoExpertises = User(
        id: 'expert_789',
        name: 'Bob Johnson',
        email: 'bob@example.com',
        roles: ['Expert'],
        languages: ['English'],
        expertises: [],
        fcmTokens: [],
        notificationsEnabled: true,
      );

      final card = ExpertCard(expert: expertNoExpertises);

      expect(card.expert.expertises, isEmpty);
    });

  });
}
