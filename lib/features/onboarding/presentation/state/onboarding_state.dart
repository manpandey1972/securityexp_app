import 'package:greenhive_app/data/models/skill.dart';

/// Onboarding form state model
///
/// Immutable state container for user onboarding form
class OnboardingState {
  /// User display name
  final String displayName;

  /// User bio/description
  final String bio;

  /// Whether user is marked as expert
  final bool isExpert;

  /// Whether user is marked as merchant
  final bool isMerchant;

  /// Selected skill IDs
  final List<String> selectedSkillIds;

  /// Selected language options
  final List<String> selectedLanguages;

  /// All available skills
  final List<Skill> allSkills;

  /// Filtered skills based on search
  final List<Skill> filteredSkills;

  /// Skill search query
  final String skillSearchQuery;

  /// Whether currently loading skills
  final bool loadingSkills;

  /// Whether currently saving profile
  final bool saving;

  /// Whether form has been submitted and validated
  final bool formSubmitted;

  /// Error message, if any
  final String? error;

  const OnboardingState({
    this.displayName = '',
    this.bio = '',
    this.isExpert = false,
    this.isMerchant = false,
    this.selectedSkillIds = const [],
    this.selectedLanguages = const [],
    this.allSkills = const [],
    this.filteredSkills = const [],
    this.skillSearchQuery = '',
    this.loadingSkills = false,
    this.saving = false,
    this.formSubmitted = false,
    this.error,
  });

  /// Create a copy of this state with optional new values
  OnboardingState copyWith({
    String? displayName,
    String? bio,
    bool? isExpert,
    bool? isMerchant,
    List<String>? selectedSkillIds,
    List<String>? selectedLanguages,
    List<Skill>? allSkills,
    List<Skill>? filteredSkills,
    String? skillSearchQuery,
    bool? loadingSkills,
    bool? saving,
    bool? formSubmitted,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      isExpert: isExpert ?? this.isExpert,
      isMerchant: isMerchant ?? this.isMerchant,
      selectedSkillIds: selectedSkillIds ?? this.selectedSkillIds,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      allSkills: allSkills ?? this.allSkills,
      filteredSkills: filteredSkills ?? this.filteredSkills,
      skillSearchQuery: skillSearchQuery ?? this.skillSearchQuery,
      loadingSkills: loadingSkills ?? this.loadingSkills,
      saving: saving ?? this.saving,
      formSubmitted: formSubmitted ?? this.formSubmitted,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Check if form is valid
  bool get isFormValid {
    return displayName.trim().isNotEmpty &&
        (isExpert || isMerchant) &&
        (isExpert ? selectedSkillIds.isNotEmpty : true) &&
        selectedLanguages.isNotEmpty;
  }

  @override
  String toString() {
    return 'OnboardingState(displayName: $displayName, expert: $isExpert, '
        'merchant: $isMerchant, skills: ${selectedSkillIds.length}, '
        'languages: ${selectedLanguages.length}, saving: $saving, error: $error)';
  }
}
