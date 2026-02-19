import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/profile/services/skills_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/features/onboarding/presentation/state/onboarding_state.dart';

/// Onboarding view model
///
/// Manages all business logic for user onboarding:
/// - Form state management
/// - Skill loading and filtering
/// - Profile creation
class OnboardingViewModel extends ChangeNotifier {
  final SkillsService _skillsService;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'OnboardingViewModel';

  OnboardingState _state = const OnboardingState();
  OnboardingState get state => _state;

  // Top 11 languages for onboarding
  static const List<String> topLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Portuguese',
    'Hindi',
    'Punjabi',
    'Chinese (Mandarin)',
    'Arabic',
    'Japanese',
    'Korean',
  ];

  OnboardingViewModel({required SkillsService skillsService})
    : _skillsService = skillsService;

  /// Initialize the ViewModel
  Future<void> initialize() async {
    await _loadSkills();
  }

  /// Load all available skills
  Future<void> _loadSkills() async {
    _state = _state.copyWith(loadingSkills: true, clearError: true);
    notifyListeners();

    try {
      final skills = await _skillsService.getAllSkills();
      _state = _state.copyWith(
        allSkills: skills,
        filteredSkills: skills,
        loadingSkills: false,
        clearError: true,
      );
      notifyListeners();
    } catch (e, stackTrace) {
      _log.error('Error loading skills', error: e, stackTrace: stackTrace, tag: _tag);
      _state = _state.copyWith(
        loadingSkills: false,
        error: 'Failed to load skills',
      );
      notifyListeners();
    }
  }

  /// Update display name
  void setDisplayName(String name) {
    _state = _state.copyWith(displayName: name, clearError: true);
    notifyListeners();
  }

  /// Update bio
  void setBio(String bio) {
    _state = _state.copyWith(bio: bio);
    notifyListeners();
  }

  /// Toggle expert status
  void setIsExpert(bool value) {
    _state = _state.copyWith(isExpert: value, clearError: true);
    notifyListeners();
  }

  /// Toggle merchant status
  void setIsMerchant(bool value) {
    _state = _state.copyWith(isMerchant: value, clearError: true);
    notifyListeners();
  }

  /// Search and filter skills
  void searchSkills(String query) {
    final filtered = query.isEmpty
        ? _state.allSkills
        : _state.allSkills
              .where(
                (skill) =>
                    skill.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

    _state = _state.copyWith(skillSearchQuery: query, filteredSkills: filtered);
    notifyListeners();
  }

  /// Toggle skill selection
  void toggleSkill(String skillId) {
    final updated = List<String>.from(_state.selectedSkillIds);
    if (updated.contains(skillId)) {
      updated.remove(skillId);
    } else {
      updated.add(skillId);
    }
    _state = _state.copyWith(selectedSkillIds: updated, clearError: true);
    notifyListeners();
  }

  /// Toggle language selection
  void toggleLanguage(String language) {
    final updated = List<String>.from(_state.selectedLanguages);
    if (updated.contains(language)) {
      updated.remove(language);
    } else {
      updated.add(language);
    }
    _state = _state.copyWith(selectedLanguages: updated, clearError: true);
    notifyListeners();
  }

  /// Validate form
  bool validateForm() {
    // Check display name
    if (_state.displayName.trim().isEmpty) {
      _state = _state.copyWith(error: 'Please enter your name');
      notifyListeners();
      return false;
    }

    // Check role selection
    if (!_state.isExpert && !_state.isMerchant) {
      _state = _state.copyWith(error: 'Please select at least one role');
      notifyListeners();
      return false;
    }

    // Check skills if expert
    if (_state.isExpert && _state.selectedSkillIds.isEmpty) {
      _state = _state.copyWith(error: 'Please select at least one skill');
      notifyListeners();
      return false;
    }

    // Check languages
    if (_state.selectedLanguages.isEmpty) {
      _state = _state.copyWith(error: 'Please select at least one language');
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Submit form and create profile
  Future<void> submitForm() async {
    if (!validateForm()) {
      return;
    }

    _state = _state.copyWith(
      saving: true,
      formSubmitted: true,
      clearError: true,
    );
    notifyListeners();

    try {
      // Prepare role string
      final roles = <String>[];
      if (_state.isExpert) roles.add('expert');
      if (_state.isMerchant) roles.add('merchant');

      // Create profile object based on roles
      // For simplicity, this is a placeholder - actual implementation would create
      // proper profile objects per role

      // Call API to update profile
      await ErrorHandler.handle<void>(
        operation: () async {
          // This would make an API call to save the profile
          // For now, we'll just update the UserProfileService

          // In a real implementation, you'd call:
          // await _apiService.updateUserProfile({
          //   'displayName': _state.displayName,
          //   'bio': _state.bio,
          //   'roles': roles,
          //   'skills': _state.isExpert ? _state.selectedSkillIds : [],
          //   'languages': _state.selectedLanguages,
          // });

          _state = _state.copyWith(saving: false, clearError: true);
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      _log.error('Error submitting form', error: e, stackTrace: stackTrace, tag: _tag);
      _state = _state.copyWith(
        saving: false,
        error: 'Failed to create profile: $e',
      );
      notifyListeners();
    }
  }

  /// Reset form to initial state
  void resetForm() {
    _state = const OnboardingState();
    notifyListeners();
  }
}
