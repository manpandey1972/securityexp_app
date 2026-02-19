// UserProfileViewModel tests
//
// Tests for the user profile view model.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:greenhive_app/features/profile/presentation/view_models/user_profile_view_model.dart';
import 'package:greenhive_app/features/profile/presentation/state/user_profile_state.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

import '../../../helpers/service_mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUserRepository mockUserRepository;
  late MockSkillsService mockSkillsService;
  late MockBiometricAuthService mockBiometricService;
  late MockProfilePictureService mockProfilePictureService;
  late MockAppLogger mockAppLogger;
  late MockFirebaseAuth mockAuth;
  late UserProfileViewModel viewModel;

  final testUser = User(
    id: 'user-123',
    name: 'Test User',
    email: 'test@example.com',
    phone: '+1234567890',
    roles: ['Expert', 'Merchant'],
    languages: ['English', 'Spanish'],
    expertises: ['skill-1', 'skill-2'],
    bio: 'Test bio',
  );

  final testSkills = [
    Skill(id: 'skill-1', name: 'Flutter', category: 'Tech', tags: ['mobile']),
    Skill(id: 'skill-2', name: 'Dart', category: 'Tech', tags: ['language']),
    Skill(id: 'skill-3', name: 'Firebase', category: 'Tech', tags: ['backend']),
  ];

  // Helper to stub all required mocks for initialize()
  void stubForInitialize() {
    when(mockSkillsService.getAllSkills())
        .thenAnswer((_) async => testSkills);
    when(mockBiometricService.isBiometricAvailable())
        .thenAnswer((_) async => false);
    when(mockBiometricService.isBiometricEnabled())
        .thenAnswer((_) async => false);
    when(mockBiometricService.getBiometricTypeName())
        .thenAnswer((_) async => 'Biometric');
    when(mockUserRepository.getCurrentUserProfile())
        .thenAnswer((_) async => testUser);
  }

  setUp(() {
    mockUserRepository = MockUserRepository();
    mockSkillsService = MockSkillsService();
    mockBiometricService = MockBiometricAuthService();
    mockProfilePictureService = MockProfilePictureService();
    mockAppLogger = MockAppLogger();
    mockAuth = MockFirebaseAuth();

    // Register mock AppLogger
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    viewModel = UserProfileViewModel(
      userRepository: mockUserRepository,
      skillsService: mockSkillsService,
      biometricService: mockBiometricService,
      profilePictureService: mockProfilePictureService,
      auth: mockAuth,
    );
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('UserProfileViewModel', () {
    group('initial state', () {
      test('should have default empty state', () {
        expect(viewModel.state.displayName, '');
        expect(viewModel.state.bio, '');
        expect(viewModel.state.isExpert, false);
        expect(viewModel.state.isMerchant, false);
        expect(viewModel.state.selectedSkillIds, isEmpty);
        expect(viewModel.state.selectedLanguages, isEmpty);
        expect(viewModel.state.loadingProfile, true); // Defaults to true
        expect(viewModel.state.loadingSkills, false);
        expect(viewModel.state.error, isNull);
      });
    });

    group('topLanguages', () {
      test('should have 11 top languages', () {
        expect(UserProfileViewModel.topLanguages.length, 11);
      });

      test('should include English first', () {
        expect(UserProfileViewModel.topLanguages.first, 'English');
      });

      test('should include common languages', () {
        expect(UserProfileViewModel.topLanguages, containsAll([
          'English',
          'Spanish',
          'French',
          'German',
          'Hindi',
          'Chinese (Mandarin)',
        ]));
      });
    });

    group('setDisplayName', () {
      test('should update display name', () {
        viewModel.setDisplayName('New Name');
        expect(viewModel.state.displayName, 'New Name');
      });

      test('should notify listeners', () {
        bool notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.setDisplayName('New Name');

        expect(notified, true);
      });
    });

    group('setBio', () {
      test('should update bio', () {
        viewModel.setBio('New bio text');
        expect(viewModel.state.bio, 'New bio text');
      });
    });

    group('setIsExpert', () {
      test('should update expert status', () {
        viewModel.setIsExpert(true);
        expect(viewModel.state.isExpert, true);

        viewModel.setIsExpert(false);
        expect(viewModel.state.isExpert, false);
      });
    });

    group('setIsMerchant', () {
      test('should update merchant status', () {
        viewModel.setIsMerchant(true);
        expect(viewModel.state.isMerchant, true);

        viewModel.setIsMerchant(false);
        expect(viewModel.state.isMerchant, false);
      });
    });

    group('searchSkills', () {
      test('should filter skills by query', () async {
        stubForInitialize();

        await viewModel.initialize();
        viewModel.searchSkills('Flu');

        expect(viewModel.state.filteredSkills.length, 1);
        expect(viewModel.state.filteredSkills.first.name, 'Flutter');
      });

      test('should show all skills when query is empty', () async {
        stubForInitialize();

        await viewModel.initialize();
        viewModel.searchSkills('Flu');
        viewModel.searchSkills('');

        expect(viewModel.state.filteredSkills.length, 3);
      });

      test('should be case insensitive', () async {
        stubForInitialize();

        await viewModel.initialize();
        viewModel.searchSkills('FLUTTER');

        expect(viewModel.state.filteredSkills.length, 1);
      });
    });

    group('toggleSkill', () {
      test('should add skill when not selected', () {
        viewModel.toggleSkill('skill-1');
        expect(viewModel.state.selectedSkillIds, contains('skill-1'));
      });

      test('should remove skill when already selected', () {
        viewModel.toggleSkill('skill-1');
        viewModel.toggleSkill('skill-1');
        expect(viewModel.state.selectedSkillIds, isNot(contains('skill-1')));
      });

      test('should allow multiple skills', () {
        viewModel.toggleSkill('skill-1');
        viewModel.toggleSkill('skill-2');
        viewModel.toggleSkill('skill-3');

        expect(viewModel.state.selectedSkillIds.length, 3);
      });
    });

    group('toggleLanguage', () {
      test('should add language when not selected', () {
        viewModel.toggleLanguage('English');
        expect(viewModel.state.selectedLanguages, contains('English'));
      });

      test('should remove language when already selected', () {
        viewModel.toggleLanguage('English');
        viewModel.toggleLanguage('English');
        expect(viewModel.state.selectedLanguages, isNot(contains('English')));
      });

      test('should allow multiple languages', () {
        viewModel.toggleLanguage('English');
        viewModel.toggleLanguage('Spanish');
        viewModel.toggleLanguage('French');

        expect(viewModel.state.selectedLanguages.length, 3);
      });
    });

    group('hasChanges', () {
      test('should return false when no changes made', () async {
        stubForInitialize();

        await viewModel.initialize();

        expect(viewModel.state.hasChanges, false);
      });

      test('should return true when display name changed', () async {
        stubForInitialize();

        await viewModel.initialize();
        viewModel.setDisplayName('Different Name');

        expect(viewModel.state.hasChanges, true);
      });

      test('should return true when bio changed', () async {
        stubForInitialize();

        await viewModel.initialize();
        viewModel.setBio('Different bio');

        expect(viewModel.state.hasChanges, true);
      });

      test('should return true when skills changed', () async {
        stubForInitialize();

        await viewModel.initialize();
        viewModel.toggleSkill('new-skill');

        expect(viewModel.state.hasChanges, true);
      });
    });
  });

  group('UserProfileState', () {
    test('should have default values', () {
      const state = UserProfileState();

      expect(state.displayName, '');
      expect(state.bio, '');
      expect(state.isExpert, false);
      expect(state.isMerchant, false);
      expect(state.selectedSkillIds, isEmpty);
      expect(state.selectedLanguages, isEmpty);
      expect(state.loadingProfile, true); // Defaults to true
      expect(state.loadingSkills, false);
      expect(state.savingProfile, false);
      expect(state.error, isNull);
    });

    test('copyWith should update specified fields', () {
      const original = UserProfileState();
      final updated = original.copyWith(
        displayName: 'John',
        bio: 'Bio text',
        isExpert: true,
      );

      expect(updated.displayName, 'John');
      expect(updated.bio, 'Bio text');
      expect(updated.isExpert, true);
      expect(updated.isMerchant, false); // Unchanged
    });

    test('copyWith clearError should clear error', () {
      const state = UserProfileState(error: 'Some error');
      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });

    test('isFormValid should check displayName and hasChanges', () {
      const state1 = UserProfileState(displayName: 'John', hasChanges: true);
      const state2 = UserProfileState(displayName: '', hasChanges: true);
      const state3 = UserProfileState(displayName: 'John', hasChanges: false);
      const state4 = UserProfileState(displayName: '   ', hasChanges: true);

      expect(state1.isFormValid, true);
      expect(state2.isFormValid, false); // Empty displayName
      expect(state3.isFormValid, false); // No changes
      expect(state4.isFormValid, false); // Whitespace only displayName
    });
  });
}
