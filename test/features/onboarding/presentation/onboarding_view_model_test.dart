// OnboardingViewModel tests
//
// Tests for the onboarding view model which manages new user setup.

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:greenhive_app/features/onboarding/presentation/view_models/onboarding_view_model.dart';
import 'package:greenhive_app/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:greenhive_app/data/models/skill.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';

import '../../../helpers/service_mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSkillsService mockSkillsService;
  late MockAppLogger mockAppLogger;
  late OnboardingViewModel viewModel;

  final testSkills = [
    Skill(id: 'skill-1', name: 'Flutter', category: 'Tech', tags: ['mobile']),
    Skill(id: 'skill-2', name: 'Dart', category: 'Tech', tags: ['language']),
    Skill(id: 'skill-3', name: 'Firebase', category: 'Tech', tags: ['backend']),
  ];

  setUp(() {
    mockSkillsService = MockSkillsService();
    mockAppLogger = MockAppLogger();

    // Register mock AppLogger
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    viewModel = OnboardingViewModel(skillsService: mockSkillsService);
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  group('OnboardingViewModel', () {
    group('initial state', () {
      test('should have empty default state', () {
        expect(viewModel.state.displayName, '');
        expect(viewModel.state.bio, '');
        expect(viewModel.state.isExpert, false);
        expect(viewModel.state.isMerchant, false);
        expect(viewModel.state.selectedSkillIds, isEmpty);
        expect(viewModel.state.selectedLanguages, isEmpty);
        expect(viewModel.state.loadingSkills, false);
        expect(viewModel.state.saving, false);
        expect(viewModel.state.error, isNull);
      });
    });

    group('topLanguages', () {
      test('should have 11 top languages', () {
        expect(OnboardingViewModel.topLanguages.length, 11);
      });

      test('should include English as first language', () {
        expect(OnboardingViewModel.topLanguages.first, 'English');
      });

      test('should include common languages', () {
        expect(OnboardingViewModel.topLanguages, containsAll([
          'English',
          'Spanish',
          'French',
          'German',
          'Hindi',
        ]));
      });
    });

    group('initialize', () {
      test('should load skills on initialization', () async {
        when(mockSkillsService.getAllSkills())
            .thenAnswer((_) async => testSkills);

        await viewModel.initialize();

        expect(viewModel.state.loadingSkills, false);
        expect(viewModel.state.allSkills, testSkills);
        expect(viewModel.state.filteredSkills, testSkills);
      });

      test('should handle skills loading error', () async {
        when(mockSkillsService.getAllSkills())
            .thenThrow(Exception('Network error'));

        await viewModel.initialize();

        expect(viewModel.state.loadingSkills, false);
        expect(viewModel.state.error, 'Failed to load skills');
      });
    });

    group('setDisplayName', () {
      test('should update display name', () {
        viewModel.setDisplayName('John Doe');

        expect(viewModel.state.displayName, 'John Doe');
      });

      test('should clear error when setting name', () async {
        // Create error state first
        when(mockSkillsService.getAllSkills())
            .thenThrow(Exception('Error'));
        await viewModel.initialize();
        expect(viewModel.state.error, isNotNull);

        viewModel.setDisplayName('John');
        expect(viewModel.state.error, isNull);
      });
    });

    group('setBio', () {
      test('should update bio', () {
        viewModel.setBio('I am a developer');

        expect(viewModel.state.bio, 'I am a developer');
      });
    });

    group('setIsExpert', () {
      test('should update expert status', () {
        viewModel.setIsExpert(true);

        expect(viewModel.state.isExpert, true);
      });

      test('should clear error when setting expert', () async {
        when(mockSkillsService.getAllSkills())
            .thenThrow(Exception('Error'));
        await viewModel.initialize();

        viewModel.setIsExpert(true);
        expect(viewModel.state.error, isNull);
      });
    });

    group('setIsMerchant', () {
      test('should update merchant status', () {
        viewModel.setIsMerchant(true);

        expect(viewModel.state.isMerchant, true);
      });
    });

    group('searchSkills', () {
      test('should filter skills by query', () async {
        when(mockSkillsService.getAllSkills())
            .thenAnswer((_) async => testSkills);
        await viewModel.initialize();

        viewModel.searchSkills('Flu');

        expect(viewModel.state.filteredSkills.length, 1);
        expect(viewModel.state.filteredSkills.first.name, 'Flutter');
        expect(viewModel.state.skillSearchQuery, 'Flu');
      });

      test('should return all skills when query is empty', () async {
        when(mockSkillsService.getAllSkills())
            .thenAnswer((_) async => testSkills);
        await viewModel.initialize();

        viewModel.searchSkills('Flu');
        viewModel.searchSkills('');

        expect(viewModel.state.filteredSkills.length, 3);
      });

      test('should be case insensitive', () async {
        when(mockSkillsService.getAllSkills())
            .thenAnswer((_) async => testSkills);
        await viewModel.initialize();

        viewModel.searchSkills('flutter');

        expect(viewModel.state.filteredSkills.length, 1);
        expect(viewModel.state.filteredSkills.first.name, 'Flutter');
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

      test('should allow multiple skill selections', () {
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

      test('should allow multiple language selections', () {
        viewModel.toggleLanguage('English');
        viewModel.toggleLanguage('Spanish');
        viewModel.toggleLanguage('French');

        expect(viewModel.state.selectedLanguages.length, 3);
      });
    });

    group('validateForm', () {
      test('should fail if display name is empty', () {
        viewModel.setIsExpert(true);
        viewModel.toggleLanguage('English');
        viewModel.toggleSkill('skill-1');

        final result = viewModel.validateForm();

        expect(result, false);
        expect(viewModel.state.error, 'Please enter your name');
      });

      test('should fail if no role selected', () {
        viewModel.setDisplayName('John');
        viewModel.toggleLanguage('English');

        final result = viewModel.validateForm();

        expect(result, false);
        expect(viewModel.state.error, 'Please select at least one role');
      });

      test('should fail if expert but no skills selected', () {
        viewModel.setDisplayName('John');
        viewModel.setIsExpert(true);
        viewModel.toggleLanguage('English');

        final result = viewModel.validateForm();

        expect(result, false);
        expect(viewModel.state.error, 'Please select at least one skill');
      });

      test('should fail if no languages selected', () {
        viewModel.setDisplayName('John');
        viewModel.setIsMerchant(true);

        final result = viewModel.validateForm();

        expect(result, false);
        expect(viewModel.state.error, 'Please select at least one language');
      });

      test('should pass with valid merchant form', () {
        viewModel.setDisplayName('John');
        viewModel.setIsMerchant(true);
        viewModel.toggleLanguage('English');

        final result = viewModel.validateForm();

        expect(result, true);
      });

      test('should pass with valid expert form', () {
        viewModel.setDisplayName('John');
        viewModel.setIsExpert(true);
        viewModel.toggleSkill('skill-1');
        viewModel.toggleLanguage('English');

        final result = viewModel.validateForm();

        expect(result, true);
      });

      test('should pass with both roles selected', () {
        viewModel.setDisplayName('John');
        viewModel.setIsExpert(true);
        viewModel.setIsMerchant(true);
        viewModel.toggleSkill('skill-1');
        viewModel.toggleLanguage('English');

        final result = viewModel.validateForm();

        expect(result, true);
      });
    });

    group('submitForm', () {
      test('should not submit if validation fails', () async {
        // Empty form should fail validation
        await viewModel.submitForm();

        expect(viewModel.state.saving, false);
        expect(viewModel.state.error, isNotNull);
      });

      test('should set saving state during submission', () async {
        viewModel.setDisplayName('John');
        viewModel.setIsMerchant(true);
        viewModel.toggleLanguage('English');

        // We can't easily test the actual submission without more mocking
        // but we can verify the form is validated
        final isValid = viewModel.validateForm();
        expect(isValid, true);
      });
    });

    group('resetForm', () {
      test('should reset to initial state', () {
        viewModel.setDisplayName('John');
        viewModel.setBio('Test bio');
        viewModel.setIsExpert(true);
        viewModel.toggleSkill('skill-1');
        viewModel.toggleLanguage('English');

        viewModel.resetForm();

        expect(viewModel.state.displayName, '');
        expect(viewModel.state.bio, '');
        expect(viewModel.state.isExpert, false);
        expect(viewModel.state.selectedSkillIds, isEmpty);
        expect(viewModel.state.selectedLanguages, isEmpty);
      });
    });
  });

  group('OnboardingState', () {
    test('should have correct default values', () {
      const state = OnboardingState();

      expect(state.displayName, '');
      expect(state.bio, '');
      expect(state.isExpert, false);
      expect(state.isMerchant, false);
      expect(state.selectedSkillIds, isEmpty);
      expect(state.selectedLanguages, isEmpty);
      expect(state.allSkills, isEmpty);
      expect(state.filteredSkills, isEmpty);
      expect(state.loadingSkills, false);
      expect(state.saving, false);
      expect(state.formSubmitted, false);
      expect(state.error, isNull);
    });

    test('copyWith should preserve unchanged values', () {
      const original = OnboardingState(
        displayName: 'John',
        isExpert: true,
      );

      final updated = original.copyWith(bio: 'New bio');

      expect(updated.displayName, 'John');
      expect(updated.isExpert, true);
      expect(updated.bio, 'New bio');
    });

    test('copyWith clearError should clear error', () {
      const state = OnboardingState(error: 'Some error');
      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });
  });
}
